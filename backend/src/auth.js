import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

/**
 * Password hashing and token issuing.
 *
 * bcryptjs is used instead of bcrypt because it is pure JavaScript, so it
 * needs no native toolchain and builds identically on every deploy target.
 */

const SALT_ROUNDS = 10;

/** Seconds a login token stays valid. */
export const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7;

export function hashPassword(plain) {
  return bcrypt.hashSync(plain, SALT_ROUNDS);
}

export function verifyPassword(plain, hash) {
  return bcrypt.compareSync(plain, hash);
}

/** @param {{ id: number, name: string, email: string }} user */
export function signToken(user, secret) {
  return jwt.sign({ sub: String(user.id), email: user.email }, secret, {
    expiresIn: TOKEN_TTL_SECONDS,
  });
}

export function verifyToken(token, secret) {
  return jwt.verify(token, secret);
}

/** Shape sent to clients — never includes `password_hash`. */
export function publicUser(row) {
  return {
    id: String(row.id),
    name: row.name,
    email: row.email,
    phone: row.phone,
    address: row.address,
  };
}