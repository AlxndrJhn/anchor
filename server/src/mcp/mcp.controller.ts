import {
  Controller,
  Delete,
  Get,
  OnModuleDestroy,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  createMcpHandler,
  type McpHttpHandler,
} from '@modelcontextprotocol/server';
import { toNodeHandler } from '@modelcontextprotocol/node';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { AnchorMcpService } from './anchor-mcp.service';

/**
 * The Model Context Protocol endpoint, so Claude and other MCP clients can
 * read and write the user's notes. Serves the 2026-07-28 revision, where
 * every request stands on its own, and older clients statelessly: each
 * request carries the user's API token and gets a server of its own.
 */
@Controller('api/mcp')
@UseGuards(AuthGuard)
export class McpController implements OnModuleDestroy {
  private readonly handler: McpHttpHandler;

  constructor(anchorMcp: AnchorMcpService) {
    this.handler = createMcpHandler(({ authInfo }) =>
      anchorMcp.createServer(authInfo!.extra!.userId as string),
    );
  }

  @Post()
  post(@Req() req: AuthenticatedRequest, @Res() res: Response) {
    return this.handle(req, res);
  }

  // GET and DELETE, the old session operations, are answered 405 by the
  // handler: there are no sessions to stream from or end.
  @Get()
  stream(@Req() req: AuthenticatedRequest, @Res() res: Response) {
    return this.handle(req, res);
  }

  @Delete()
  end(@Req() req: AuthenticatedRequest, @Res() res: Response) {
    return this.handle(req, res);
  }

  private async handle(req: AuthenticatedRequest, res: Response) {
    const authInfo = {
      token: '',
      clientId: 'anchor',
      scopes: [],
      extra: { userId: req.user!.id },
    };
    await toNodeHandler({
      fetch: (request, options) =>
        this.handler.fetch(request, { ...options, authInfo }),
    })(req, res, req.body);
  }

  async onModuleDestroy() {
    await this.handler.close();
  }
}
