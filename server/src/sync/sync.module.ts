import { Module } from '@nestjs/common';
import { SyncEmitterService } from './sync-emitter.service';
import { SyncEventsService } from './sync-events.service';
import { NoteRevisionsService } from './note-revisions.service';
import { SyncMaintenanceService } from './sync-maintenance.service';
import { SharedNoteEventsService } from './shared-note-events.service';

@Module({
  providers: [
    SyncEmitterService,
    SyncEventsService,
    NoteRevisionsService,
    SyncMaintenanceService,
    SharedNoteEventsService,
  ],
  exports: [
    SyncEmitterService,
    SyncEventsService,
    NoteRevisionsService,
    SyncMaintenanceService,
    SharedNoteEventsService,
  ],
})
export class SyncModule {}
