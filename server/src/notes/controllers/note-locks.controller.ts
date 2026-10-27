import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseEnumPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../../auth/auth.guard';
import { CurrentUser } from '../../auth/decorators/current-user.decorator';
import { SetLockSecretDto, VerifyLockDto } from '../dto/note-lock.dto';
import { NoteLocksService } from '../services/note-locks.service';

enum SecretKind {
  pin = 'pin',
  pattern = 'pattern',
}

@Controller('api/note-locks')
@UseGuards(AuthGuard)
export class NoteLocksController {
  constructor(private readonly noteLocks: NoteLocksService) {}

  @Get()
  secrets(@CurrentUser('id') userId: string) {
    return this.noteLocks.secrets(userId);
  }

  @Put(':kind')
  setSecret(
    @CurrentUser('id') userId: string,
    @Param('kind', new ParseEnumPipe(SecretKind)) kind: SecretKind,
    @Body() dto: SetLockSecretDto,
  ) {
    return this.noteLocks.setSecret(userId, kind, dto.secret, dto);
  }

  @Post('verify')
  @HttpCode(200)
  verify(@CurrentUser('id') userId: string, @Body() dto: VerifyLockDto) {
    return this.noteLocks.verify(userId, dto.kind, dto.secret);
  }
}
