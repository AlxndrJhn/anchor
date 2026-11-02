import { AsyncLocalStorage } from 'async_hooks';
import type { NextFunction, Request, Response } from 'express';

interface RequestContext {
  userAgent?: string;
}

const storage = new AsyncLocalStorage<RequestContext>();

/** Makes the request's details readable deeper down, as when signing in. */
export function requestContextMiddleware(
  req: Request,
  _res: Response,
  next: NextFunction,
): void {
  storage.run({ userAgent: req.get('user-agent') }, next);
}

export function currentUserAgent(): string | undefined {
  return storage.getStore()?.userAgent;
}
