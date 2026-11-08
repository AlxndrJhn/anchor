import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { SyncModule } from '../sync/sync.module';
import { CollabSocketService } from './collab-socket.service';
import { CollabService } from './collab.service';

@Module({
  imports: [AuthModule, SyncModule],
  providers: [CollabService, CollabSocketService],
})
export class CollabModule {}
