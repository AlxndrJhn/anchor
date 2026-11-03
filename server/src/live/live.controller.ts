import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { LiveSignalDto } from './dto/live-signal.dto';
import { LiveService } from './live.service';

@Controller('api/live')
@UseGuards(AuthGuard)
export class LiveController {
  constructor(private readonly live: LiveService) {}

  @Get('config')
  config() {
    return { iceServers: this.live.iceServers() };
  }

  @Post('signal')
  @HttpCode(HttpStatus.NO_CONTENT)
  async signal(
    @CurrentUser('id') userId: string,
    @Body() signal: LiveSignalDto,
  ): Promise<void> {
    await this.live.signal(userId, signal);
  }
}
