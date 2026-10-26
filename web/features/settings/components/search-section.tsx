"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Switch } from "@/components/ui/switch";
import { toast } from "@/components/ui/toast";
import {
  getPictureSearchStatus,
  type PictureSearchStatus,
  pictureSearchStatusKey,
  setPictureSearch,
} from "@/features/picture-search/api";
import { Row, RowText, Section } from "./settings-blocks";

/** Where indexing is, in a few words. */
function progressText(status: PictureSearchStatus): string | null {
  if (!status.enabled) return null;
  const { model } = status;
  if (model.state === "downloading")
    return `Downloading the picture model… ${Math.round(model.progress * 100)}%`;
  if (model.state === "failed")
    return "The picture model couldn’t be downloaded. Turn it off and on to try again.";
  if (status.indexed < status.total)
    return `Looking at your pictures… ${status.indexed} of ${status.total}`;
  return status.total === 1
    ? "Your picture is ready to search."
    : `All ${status.total} pictures are ready to search.`;
}

export function SearchSection() {
  const queryClient = useQueryClient();
  const { data: status } = useQuery({
    queryKey: pictureSearchStatusKey,
    queryFn: getPictureSearchStatus,
    // Follows the download and the indexing while they run.
    refetchInterval: (query) => {
      const s = query.state.data;
      return s?.enabled &&
        (s.model.state === "downloading" || s.indexed < s.total)
        ? 2000
        : false;
    },
  });
  const toggle = useMutation({
    mutationFn: setPictureSearch,
    onSuccess: (next) => queryClient.setQueryData(pictureSearchStatusKey, next),
    onError: () => toast.error("Couldn’t change picture search"),
  });

  if (!status?.available) return null;
  const progress = progressText(status);
  return (
    <Section id="search" title="Search">
      <Row>
        <RowText
          title={
            <label htmlFor="picture-search">
              Find pictures by what they show
            </label>
          }
          text={
            <>
              Search for “Sonnenuntergang am Meer” or “receipt” and find notes
              with such pictures, in most languages. Your server downloads a
              model once (about 380 MB) and looks at each picture; nothing
              leaves your server.
              {progress && (
                <span className="mt-1 block text-foreground" aria-live="polite">
                  {progress}
                </span>
              )}
            </>
          }
        />
        <Switch
          id="picture-search"
          checked={status.enabled}
          disabled={toggle.isPending}
          onCheckedChange={(on) => toggle.mutate(on)}
        />
      </Row>
    </Section>
  );
}
