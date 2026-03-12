// portal/src/records/usdcx_fetcher.ts
//
// Fetch and select an unspent USDCx Token record from the Aleo REST API.
//
// USAGE PATTERN:
//   const record = await fetchBestUsdcxRecord({
//     endpoint: "https://api.explorer.provable.com/v1/testnet",
//     program_id: "test_usdcx_stablecoin.aleo",      // or the real testnet ID
//     view_key: process.env.ALEO_VIEW_KEY!,
//     minimum_amount: worker1.net_amount + worker2.net_amount,
//   });
//   // record.raw is the Token record string to pass to snarkos developer execute
//
// WHY THIS MATTERS FOR BATCH PAYROLL:
//   execute_payroll_batch_2 takes a single Token record as input.
//   The record's amount must be >= sum of all workers' net_amounts.
//   The circuit splits it internally — no wallet record juggling needed.
//   This fetcher finds the right record automatically.
//
// RECORD AMOUNT ENCODING:
//   test_usdcx_stablecoin.aleo Token records store `amount: u128`.
//   Units are USDCx minor units (6 decimal places: 1 USDC = 1_000_000u128).

import type { UsdcxRecord } from "../types/aleo_records";

export type UsdcxFetcherOptions = {
  /** Full endpoint URL including network path, e.g. https://api.explorer.provable.com/v1/testnet */
  endpoint: string;
  /** The deployed program ID for the USDCx token. Check testnet.manifest.json -> external.usdcx */
  program_id: string;
  /** Employer's Aleo view key (AViewKey1...) — used to decrypt private records */
  view_key: string;
  /** Minimum required amount in u128 minor units. Must cover sum of all workers' net_amounts. */
  minimum_amount: bigint;
  /** Optional: timeout in ms for the fetch call. Default 30000. */
  fetch_timeout_ms?: number;
};

export type UsdcxRecordResult = {
  record: UsdcxRecord;
  /** Decrypted amount in u128 minor units */
  amount: bigint;
  /** The raw record string as returned by the API — passed directly to snarkos developer execute */
  raw: string;
};

export class UsdcxFetchError extends Error {
  readonly kind: "no_records" | "insufficient_balance" | "api_error" | "parse_error";
  constructor(message: string, kind: UsdcxFetchError["kind"]) {
    super(message);
    this.name = "UsdcxFetchError";
    this.kind = kind;
  }
}

/**
 * Fetch unspent Token records from the Aleo REST API for the given program,
 * then select the record with the highest balance that meets the minimum_amount.
 *
 * The returned record.raw is the plaintext Leo record string suitable for use
 * as a snarkos developer execute argument or adapter input.
 *
 * NOTE: The Aleo REST API returns records as ciphertexts. Decryption is done
 * server-side when a view_key is provided as a query parameter. If your node
 * does not support view_key decryption on this endpoint, use the snarkos CLI
 * scan approach (scripts/scan_usdcx_records.sh) instead.
 */
export async function fetchBestUsdcxRecord(
  options: UsdcxFetcherOptions,
): Promise<UsdcxRecordResult> {
  const { endpoint, program_id, view_key, minimum_amount, fetch_timeout_ms = 30_000 } = options;

  // Strip trailing slash from endpoint
  const base = endpoint.replace(/\/$/, "");

  // Aleo REST API: GET /program/{program_id}/records/unspent?view_key={view_key}
  // Returns an array of plaintext record strings when view_key is provided.
  const url = `${base}/program/${encodeURIComponent(program_id)}/records/unspent?view_key=${encodeURIComponent(view_key)}`;

  let raw_response: unknown;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), fetch_timeout_ms);
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timer);

    if (!res.ok) {
      throw new UsdcxFetchError(
        `Aleo API returned ${res.status} ${res.statusText} for ${program_id} records`,
        "api_error",
      );
    }
    raw_response = await res.json();
  } catch (err) {
    if (err instanceof UsdcxFetchError) throw err;
    throw new UsdcxFetchError(
      `Failed to fetch USDCx records: ${err instanceof Error ? err.message : String(err)}`,
      "api_error",
    );
  }

  // Parse the response — expected: array of plaintext record strings
  const records = parseRecordList(raw_response, program_id);

  if (records.length === 0) {
    throw new UsdcxFetchError(
      `No unspent ${program_id} Token records found for this view key`,
      "no_records",
    );
  }

  // Parse amounts and filter to those meeting the minimum
  const parsed = records
    .map((raw) => ({ raw, amount: parseTokenAmount(raw) }))
    .filter((r) => r.amount !== null) as { raw: string; amount: bigint }[];

  // Sort descending by amount — pick the largest record that meets minimum
  parsed.sort((a, b) => (a.amount > b.amount ? -1 : a.amount < b.amount ? 1 : 0));

  const best = parsed.find((r) => r.amount >= minimum_amount);

  if (!best) {
    const max_available = parsed[0]?.amount ?? 0n;
    throw new UsdcxFetchError(
      `No single ${program_id} record has enough balance. ` +
        `Need ${minimum_amount} minor units, best available is ${max_available}. ` +
        `Fund your wallet with more USDCx or split the batch into smaller runs.`,
      "insufficient_balance",
    );
  }

  return {
    record: { __record_tag: "UsdcxRecord", raw: best.raw } as UsdcxRecord,
    amount: best.amount,
    raw: best.raw,
  };
}

/**
 * Parse the API response into an array of record strings.
 *
 * The Aleo REST API may return:
 *   - An array of plaintext record strings: ["{ owner: aleo1..., amount: 1000u128, ... }", ...]
 *   - An array of objects with a "record" or "plaintext" field
 *   - A single string (single record case)
 */
function parseRecordList(response: unknown, program_id: string): string[] {
  if (Array.isArray(response)) {
    return response.flatMap((item) => {
      if (typeof item === "string") return [item];
      if (typeof item === "object" && item !== null) {
        // Try common field names
        for (const key of ["record", "plaintext", "ciphertext", "data"]) {
          if (key in item && typeof (item as Record<string, unknown>)[key] === "string") {
            return [(item as Record<string, unknown>)[key] as string];
          }
        }
      }
      return [];
    });
  }

  if (typeof response === "string") {
    return [response];
  }

  throw new UsdcxFetchError(
    `Unexpected response format from ${program_id} records API: ${JSON.stringify(response).slice(0, 200)}`,
    "parse_error",
  );
}

/**
 * Extract the `amount: u128` value from a plaintext Leo record string.
 *
 * Expected formats:
 *   { owner: aleo1..., amount: 1000000u128, token_id: 1field, ... }
 *   { ..., amount: 5000000u128.private, ... }
 */
function parseTokenAmount(record_str: string): bigint | null {
  // Match "amount: <digits>u128" optionally followed by ".private" or ".public"
  const match = record_str.match(/\bamount\s*:\s*(\d+)u128/);
  if (!match) return null;
  try {
    return BigInt(match[1]);
  } catch {
    return null;
  }
}

/**
 * Convenience: compute the total net_amount needed across a batch of workers.
 * Pass this as minimum_amount to fetchBestUsdcxRecord.
 *
 * Example:
 *   const minimum = totalNetAmount([worker1, worker2]);
 *   const record = await fetchBestUsdcxRecord({ ..., minimum_amount: minimum });
 */
export function totalNetAmount(workers: { net_amount: bigint }[]): bigint {
  return workers.reduce((sum, w) => sum + w.net_amount, 0n);
}
