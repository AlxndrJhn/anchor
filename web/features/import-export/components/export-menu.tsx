"use client";

import { ChevronDown, Download, FileText, FolderArchive } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { toast } from "@/components/ui/toast";
import { isServerless } from "@/lib/local-backend/mode";
import { downloadExport } from "../api";
import type { ExportFormat } from "../types";

const ALL_CHOICES = [
  {
    format: "anchor",
    label: "Anchor backup (.zip)",
    hint: "Everything, to restore later: notes, tags and attachments",
    icon: FolderArchive,
  },
  {
    format: "markdown",
    label: "Markdown files (.zip)",
    hint: "Plain .md files for Obsidian, Nextcloud Notes and others",
    icon: FileText,
  },
] as const;

// The server writes the Markdown; without one there is only the backup.
const CHOICES = isServerless
  ? ALL_CHOICES.filter((choice) => choice.format === "anchor")
  : ALL_CHOICES;

function startExport(format: ExportFormat) {
  void toast
    .promise(downloadExport(format), {
      loading: "Preparing your export…",
      success: "Export downloaded",
      error: "Couldn’t export your notes",
      retry: () => startExport(format),
    })
    .catch(() => {});
}

export function ExportMenu() {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="secondary">
          <Download aria-hidden />
          Export
          <ChevronDown aria-hidden className="-mr-1 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-72">
        {CHOICES.map((choice) => (
          <DropdownMenuItem
            key={choice.format}
            className="items-start py-2 [&>svg]:mt-0.5"
            onSelect={() => startExport(choice.format)}
          >
            <choice.icon />
            <span className="grid gap-0.5 whitespace-normal leading-[1.35]">
              {choice.label}
              <small className="text-muted-foreground text-small">
                {choice.hint}
              </small>
            </span>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
