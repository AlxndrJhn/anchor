import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotesModule } from '../notes/notes.module';
import { SyncModule } from '../sync/sync.module';
import { LiveController } from './live.controller';
import { LiveService } from './live.service';

@Module({
  imports: [AuthModule, NotesModule, SyncModule],
  controllers: [LiveController],
  providers: [LiveService],
})
export class LiveModule {}
