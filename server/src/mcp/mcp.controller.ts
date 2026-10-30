import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { AnchorMcpService } from './anchor-mcp.service';

/**
 * The Model Context Protocol endpoint, so Claude and other MCP clients can
 * read and write the user's notes. Stateless Streamable HTTP: every request
 * carries the user's API token and gets a server of its own.
 */
@Controller('api/mcp')
@UseGuards(AuthGuard)
export class McpController {
  constructor(private readonly anchorMcp: AnchorMcpService) {}

  @Post()
  async handle(@Req() req: AuthenticatedRequest, @Res() res: Response) {
    const server = this.anchorMcp.createServer(req.user!.id);
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });
    res.on('close', () => {
      void transport.close();
      void server.close();
    });
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  }

  // Without sessions there is no stream to open and nothing to end.
  @Get()
  @HttpCode(HttpStatus.METHOD_NOT_ALLOWED)
  stream() {
    return methodNotAllowed();
  }

  @Delete()
  @HttpCode(HttpStatus.METHOD_NOT_ALLOWED)
  end() {
    return methodNotAllowed();
  }
}

function methodNotAllowed() {
  return {
    jsonrpc: '2.0',
    error: { code: -32000, message: 'Method not allowed.' },
    id: null,
  };
}
