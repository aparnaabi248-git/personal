/**
 * Tiny request validators.
 *
 * Each returns the cleaned value, or throws a `ValidationError` listing every
 * problem at once so the client can show them all in a single response.
 */

export class ValidationError extends Error {
  /** @param {string[]} fields */
  constructor(fields) {
    super('Validation failed');
    this.name = 'ValidationError';
    this.status = 400;
    this.fields = fields;
  }
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function requireString(value, field, { min = 1, max = 500 } = {}) {
  if (typeof value !== 'string' || value.trim().length < min) {
    throw new ValidationError([`${field} is required`]);
  }
  const trimmed = value.trim();
  if (trimmed.length > max) {
    throw new ValidationError([`${field} must be at most ${max} characters`]);
  }
  return trimmed;
}

export function optionalString(value, field, { max = 500 } = {}) {
  if (value === undefined || value === null || value === '') return '';
  return requireString(value, field, { min: 0, max });
}

export function requireEmail(value) {
  const email = requireString(value, 'email', { max: 254 }).toLowerCase();
  if (!EMAIL_RE.test(email)) {
    throw new ValidationError(['email is not valid']);
  }
  return email;
}

export function requirePassword(value) {
  if (typeof value !== 'string' || value.length < 6) {
    throw new ValidationError(['password must be at least 6 characters']);
  }
  if (value.length > 200) {
    throw new ValidationError(['password must be at most 200 characters']);
  }
  return value;
}

/**
 * Validates a money amount.
 *
 * Rounded to two decimals so repeated arithmetic cannot accumulate float
 * error. Kept as REAL because the Flutter client models money as `double`.
 */
export function requireAmount(value, field = 'amount') {
  const amount = typeof value === 'string' ? Number(value) : value;
  if (typeof amount !== 'number' || !Number.isFinite(amount)) {
    throw new ValidationError([`${field} must be a number`]);
  }
  if (amount <= 0) {
    throw new ValidationError([`${field} must be greater than zero`]);
  }
  if (amount > 1e12) {
    throw new ValidationError([`${field} is too large`]);
  }
  return Math.round(amount * 100) / 100;
}

export function requireType(value) {
  if (value !== 'Income' && value !== 'Expense') {
    throw new ValidationError(["type must be 'Income' or 'Expense'"]);
  }
  return value;
}

/**
 * Accepts an ISO `YYYY-MM-DD` or full ISO timestamp and stores `YYYY-MM-DD`.
 *
 * Storing a plain date keeps month bucketing simple; the Flutter client sends
 * whatever `DateTime.toIso8601String()` produced.
 */
export function requireDate(value, field = 'date') {
  if (typeof value !== 'string' || value.trim() === '') {
    // Fall back to today so a missing date is never a hard failure.
    return new Date().toISOString().slice(0, 10);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new ValidationError([`${field} is not a valid date`]);
  }
  return parsed.toISOString().slice(0, 10);
}

/** Validates a `YYYY-MM` string, defaulting to the current month. */
export function optionalMonth(value) {
  if (value === undefined || value === null || value === '') {
    return new Date().toISOString().slice(0, 7);
  }
  if (typeof value !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(value)) {
    throw new ValidationError(["month must look like 'YYYY-MM'"]);
  }
  return value;
}