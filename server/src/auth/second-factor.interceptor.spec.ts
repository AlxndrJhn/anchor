import { describe, expect, it, vi } from 'vitest';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { of } from 'rxjs';
import { SecondFactorInterceptor } from './second-factor.interceptor';
import { SecondFactorService } from './second-factor.service';
import { AllowBeforeSecondFactor } from './decorators/allow-before-second-factor.decorator';

class Routes {
  notes() {}
  @AllowBeforeSecondFactor()
  setUp() {}
}

/** Who gets through once the grace period is over. */
describe('SecondFactorInterceptor', () => {
  const run = (
    handler: keyof Routes,
    { user, blocked }: { user?: { id: string }; blocked: boolean },
  ) => {
    const interceptor = new SecondFactorInterceptor(new Reflector(), {
      isBlocked: vi.fn(() => Promise.resolve(blocked)),
    } as unknown as SecondFactorService);
    const context = {
      getType: () => 'http',
      // eslint-disable-next-line @typescript-eslint/unbound-method -- only its metadata is read
      getHandler: () => Routes.prototype[handler],
      getClass: () => Routes,
      switchToHttp: () => ({ getRequest: () => ({ user }) }),
    } as unknown as ExecutionContext;
    return interceptor.intercept(context, { handle: () => of('ok') });
  };

  it('turns someone blocked away from everything else', async () => {
    await expect(
      run('notes', { user: { id: 'u1' }, blocked: true }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('lets them set one up', async () => {
    await expect(
      run('setUp', { user: { id: 'u1' }, blocked: true }),
    ).resolves.toBeDefined();
  });

  it('lets everyone else through', async () => {
    await expect(
      run('notes', { user: { id: 'u1' }, blocked: false }),
    ).resolves.toBeDefined();
  });

  it('leaves routes without a signed-in person to their own checks', async () => {
    await expect(run('notes', { blocked: true })).resolves.toBeDefined();
  });
});
