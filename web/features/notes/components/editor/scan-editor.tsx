"use client";

import {
  Crop,
  Eye,
  GripVertical,
  ImagePlus,
  RotateCcw,
  RotateCw,
  Trash2,
} from "lucide-react";
import * as React from "react";
import { Button, IconButton } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SegmentedControl } from "@/components/ui/segmented-control";
import { toast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";
import { detectCorners, pagePreview } from "../../scan-render";
import {
  type Corners,
  isPageShape,
  newScanPage,
  type PageSize,
  PDF_MARGINS,
  type PdfQuality,
  PROFILE_LABELS,
  SCAN_PROFILES,
  type ScanDocument,
  type ScanPage,
  type ScanProfile,
  WHOLE,
} from "../../scans";

export interface ScanEditorHandle {
  current: () => ScanDocument;
}

interface ScanEditorProps {
  initial: ScanDocument;
  load: (id: string) => Promise<Blob>;
  /** Uploads photos to the note; their attachment ids. */
  upload?: (files: File[]) => Promise<string[]>;
  onChange: (scan: ScanDocument) => void;
}

/** A page's picture drawn small, re-rendered when its settings change. */
function PagePreview({
  load,
  page,
  size,
  className,
  alt,
}: {
  load: (id: string) => Promise<Blob>;
  page: ScanPage;
  size: number;
  className?: string;
  alt: string;
}) {
  const [url, setUrl] = React.useState<string | null>(null);
  const key = JSON.stringify(page);
  React.useEffect(() => {
    let live = true;
    const settled = JSON.parse(key) as ScanPage;
    // Waits a moment while a slider is dragged.
    const timer = setTimeout(() => {
      pagePreview(load, settled, size, "editor").then(
        (next) => live && setUrl(next),
        () => undefined,
      );
    }, 120);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [key, load, size]);
  return url ? (
    <img src={url} alt={alt} className={className} draggable={false} />
  ) : (
    <span
      role="img"
      className={cn(className, "scan-loading")}
      aria-label={alt}
    />
  );
}

/** The original photo with the page's four corners to drag. */
function CornerEditor({
  load,
  page,
  onCorners,
}: {
  load: (id: string) => Promise<Blob>;
  page: ScanPage;
  onCorners: (corners: Corners) => void;
}) {
  const [url, setUrl] = React.useState<string | null>(null);
  const [ratio, setRatio] = React.useState<number | null>(null);
  const box = React.useRef<HTMLDivElement>(null);
  const corners = page.corners ?? WHOLE;
  const dragging = React.useRef<number | null>(null);

  React.useEffect(() => {
    let live = true;
    let made: string | null = null;
    setUrl(null);
    setRatio(null);
    load(page.id).then(
      (blob) => {
        if (!live) return;
        made = URL.createObjectURL(blob);
        setUrl(made);
      },
      () => undefined,
    );
    return () => {
      live = false;
      if (made) URL.revokeObjectURL(made);
    };
  }, [load, page.id]);

  const shareAt = (e: React.PointerEvent) => {
    const rect = box.current?.getBoundingClientRect();
    if (!rect) return null;
    return [
      Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width)),
      Math.min(1, Math.max(0, (e.clientY - rect.top) / rect.height)),
    ] as [number, number];
  };

  const move = (e: React.PointerEvent) => {
    const i = dragging.current;
    if (i === null) return;
    const at = shareAt(e);
    if (!at) return;
    const next = [...corners] as Corners;
    next[i] = at;
    if (isPageShape(next)) onCorners(next);
  };

  const nudge = (i: number, e: React.KeyboardEvent) => {
    const step = e.shiftKey ? 0.02 : 0.005;
    const d = {
      ArrowLeft: [-step, 0],
      ArrowRight: [step, 0],
      ArrowUp: [0, -step],
      ArrowDown: [0, step],
    }[e.key];
    if (!d) return;
    e.preventDefault();
    const next = [...corners] as Corners;
    next[i] = [
      Math.min(1, Math.max(0, corners[i][0] + d[0])),
      Math.min(1, Math.max(0, corners[i][1] + d[1])),
    ];
    if (isPageShape(next)) onCorners(next);
  };

  const names = ["Top left", "Top right", "Bottom right", "Bottom left"];
  return (
    <div className="scan-stage">
      {url && (
        <div
          ref={box}
          className="scan-photo"
          style={ratio ? { aspectRatio: `${ratio}` } : undefined}
          onPointerMove={move}
          onPointerUp={() => {
            dragging.current = null;
          }}
          onPointerCancel={() => {
            dragging.current = null;
          }}
        >
          <img
            src={url}
            alt="The page as photographed"
            draggable={false}
            onLoad={(e) =>
              setRatio(
                e.currentTarget.naturalWidth / e.currentTarget.naturalHeight,
              )
            }
          />
          {ratio && (
            <svg
              className="scan-frame"
              viewBox="0 0 1000 1000"
              preserveAspectRatio="none"
              aria-hidden="true"
            >
              <path
                className="scan-shade"
                fillRule="evenodd"
                d={`M0 0H1000V1000H0Z M${corners
                  .map(([x, y]) => `${x * 1000} ${y * 1000}`)
                  .join(" L")}Z`}
              />
              <polygon
                className="scan-outline"
                points={corners
                  .map(([x, y]) => `${x * 1000},${y * 1000}`)
                  .join(" ")}
              />
            </svg>
          )}
          {ratio &&
            corners.map(([x, y], i) => (
              <button
                key={i}
                type="button"
                className="scan-handle"
                style={{ left: `${x * 100}%`, top: `${y * 100}%` }}
                aria-label={`${names[i]} corner`}
                onPointerDown={(e) => {
                  e.preventDefault();
                  dragging.current = i;
                  box.current?.setPointerCapture(e.pointerId);
                }}
                onKeyDown={(e) => nudge(i, e)}
              />
            ))}
        </div>
      )}
    </div>
  );
}

function Slider({
  label,
  value,
  min,
  max,
  onChange,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  onChange: (value: number) => void;
}) {
  const id = React.useId();
  return (
    <div className="scan-slider">
      <label htmlFor={id}>
        <span>{label}</span>
        <output htmlFor={id}>{value}</output>
      </label>
      <input
        id={id}
        type="range"
        min={min}
        max={max}
        step={1}
        value={value}
        onChange={(e) => onChange(Number(e.currentTarget.value))}
        onDoubleClick={() => onChange(label === "Clean up" ? 50 : 0)}
      />
    </div>
  );
}

/**
 * Changes a scan: its pages (order, turn, delete, add), each page's corners
 * on the original photo, its colour profile and adjustments, and how the
 * PDF is laid out.
 */
export const ScanEditor = React.forwardRef<ScanEditorHandle, ScanEditorProps>(
  ({ initial, load, upload, onChange }, ref) => {
    const [scan, setScan] = React.useState(initial);
    const [selected, setSelected] = React.useState(0);
    const [showResult, setShowResult] = React.useState(true);
    const [adding, setAdding] = React.useState(false);
    const [dragFrom, setDragFrom] = React.useState<number | null>(null);
    const input = React.useRef<HTMLInputElement>(null);
    const titleId = React.useId();
    const latest = React.useRef(scan);
    latest.current = scan;

    React.useImperativeHandle(ref, () => ({ current: () => latest.current }));

    const change = (next: ScanDocument) => {
      setScan(next);
      onChange(next);
    };
    const page = scan.pages[Math.min(selected, scan.pages.length - 1)];
    const setPage = (patch: Partial<ScanPage>) => {
      const index = scan.pages.indexOf(page);
      change({
        ...scan,
        pages: scan.pages.map((p, i) => (i === index ? { ...p, ...patch } : p)),
      });
    };
    const turn = (by: number) =>
      setPage({ rotate: ((((page.rotate + by) % 360) + 360) % 360) as 0 });
    const removePage = (index: number) => {
      change({ ...scan, pages: scan.pages.filter((_, i) => i !== index) });
      setSelected((s) =>
        Math.max(0, s > index ? s - 1 : Math.min(s, scan.pages.length - 2)),
      );
    };
    const movePage = (from: number, to: number) => {
      if (from === to) return;
      const pages = [...scan.pages];
      const [moved] = pages.splice(from, 1);
      pages.splice(to, 0, moved);
      change({ ...scan, pages });
      setSelected(to);
    };
    const applyToAll = () => {
      const { profile, brightness, contrast, threshold, cleanup } = page;
      change({
        ...scan,
        pages: scan.pages.map((p) => ({
          ...p,
          profile,
          brightness,
          contrast,
          threshold,
          cleanup,
        })),
      });
      toast.success("Look applied to every page");
    };

    const addPictures = async (files: File[]) => {
      if (!upload || !files.length) return;
      setAdding(true);
      try {
        const corners = await Promise.all(
          files.map((f) => detectCorners(f).catch(() => null)),
        );
        const ids = await upload(files);
        const added = ids.map((id, i) =>
          newScanPage(id, corners[i] ?? undefined),
        );
        const next = {
          ...latest.current,
          pages: [...latest.current.pages, ...added],
        };
        change(next);
        setSelected(next.pages.length - 1);
      } catch {
        toast.error("Couldn’t add the pictures");
      } finally {
        setAdding(false);
      }
    };

    if (!page)
      return (
        <div className="scan-empty">
          <p>No pages left.</p>
          {upload && (
            <Button type="button" onClick={() => input.current?.click()}>
              <ImagePlus /> Add pictures
            </Button>
          )}
          <input
            ref={input}
            type="file"
            accept="image/*"
            multiple
            hidden
            onChange={(e) => {
              void addPictures([...(e.currentTarget.files ?? [])]);
              e.currentTarget.value = "";
            }}
          />
        </div>
      );

    const index = scan.pages.indexOf(page);
    return (
      <div className="scan-editor">
        <ol className="scan-list" aria-label="Pages">
          {scan.pages.map((p, i) => (
            <li
              // By photo, so a moved page keeps its element and its focus.
              key={p.id}
              className={cn(
                "scan-list-item",
                i === index && "is-picked",
                dragFrom !== null && dragFrom !== i && "is-target",
              )}
              draggable
              onDragStart={(e) => {
                setDragFrom(i);
                e.dataTransfer.effectAllowed = "move";
              }}
              onDragOver={(e) => {
                if (dragFrom === null) return;
                e.preventDefault();
              }}
              onDrop={(e) => {
                e.preventDefault();
                if (dragFrom !== null) movePage(dragFrom, i);
                setDragFrom(null);
              }}
              onDragEnd={() => setDragFrom(null)}
            >
              <button
                type="button"
                className="scan-list-pick"
                aria-current={i === index}
                onClick={() => setSelected(i)}
                onKeyDown={(e) => {
                  if (e.altKey && e.key === "ArrowUp" && i > 0) {
                    e.preventDefault();
                    movePage(i, i - 1);
                  } else if (
                    e.altKey &&
                    e.key === "ArrowDown" &&
                    i < scan.pages.length - 1
                  ) {
                    e.preventDefault();
                    movePage(i, i + 1);
                  }
                }}
              >
                <GripVertical className="scan-grip" aria-hidden="true" />
                <PagePreview
                  load={load}
                  page={p}
                  size={200}
                  className="scan-list-thumb"
                  alt={`Page ${i + 1}`}
                />
                <span className="scan-list-number">{i + 1}</span>
              </button>
            </li>
          ))}
          {upload && (
            <li>
              <Button
                type="button"
                variant="secondary"
                className="w-full"
                aria-busy={adding}
                disabled={adding}
                onClick={() => input.current?.click()}
              >
                <ImagePlus /> {adding ? "Adding…" : "Add pictures"}
              </Button>
              <input
                ref={input}
                type="file"
                accept="image/*"
                multiple
                hidden
                onChange={(e) => {
                  void addPictures([...(e.currentTarget.files ?? [])]);
                  e.currentTarget.value = "";
                }}
              />
            </li>
          )}
        </ol>

        <div className="scan-center">
          <div className="scan-center-bar">
            <SegmentedControl
              aria-label="Show"
              size="sm"
              value={showResult ? "result" : "photo"}
              onValueChange={(v) => setShowResult(v === "result")}
              options={[
                { value: "result", label: "Result", icon: <Eye /> },
                { value: "photo", label: "Corners", icon: <Crop /> },
              ]}
            />
            <span className="scan-center-tools">
              <IconButton size="sm" label="Turn left" onClick={() => turn(-90)}>
                <RotateCcw />
              </IconButton>
              <IconButton size="sm" label="Turn right" onClick={() => turn(90)}>
                <RotateCw />
              </IconButton>
              <IconButton
                size="sm"
                label="Delete page"
                onClick={() => removePage(index)}
              >
                <Trash2 />
              </IconButton>
            </span>
          </div>
          {showResult ? (
            <div className="scan-stage">
              <PagePreview
                load={load}
                page={page}
                size={1200}
                className="scan-result"
                alt={`Page ${index + 1}, as it comes out`}
              />
            </div>
          ) : (
            <CornerEditor
              load={load}
              page={page}
              onCorners={(corners) => setPage({ corners })}
            />
          )}
          {!showResult && (
            <div className="scan-center-foot">
              <Button
                type="button"
                variant="quiet"
                size="sm"
                onClick={() => setPage({ corners: undefined })}
              >
                Whole picture
              </Button>
              <Button
                type="button"
                variant="quiet"
                size="sm"
                onClick={async () => {
                  const found = await detectCorners(await load(page.id)).catch(
                    () => null,
                  );
                  if (found) setPage({ corners: found });
                  else toast.error("No page found in this picture");
                }}
              >
                Find the page
              </Button>
            </div>
          )}
        </div>

        <div className="scan-side">
          <section aria-label="Look">
            <h3>Look</h3>
            <SegmentedControl
              aria-label="Color profile"
              variant="tiles"
              full
              // Two by two, so each name fits on its tile.
              columns={2}
              value={page.profile}
              onValueChange={(profile: ScanProfile) => setPage({ profile })}
              options={SCAN_PROFILES.map((value) => ({
                value,
                label: PROFILE_LABELS[value],
              }))}
            />
            <Slider
              label="Brightness"
              value={page.brightness}
              min={-100}
              max={100}
              onChange={(brightness) => setPage({ brightness })}
            />
            <Slider
              label="Contrast"
              value={page.contrast}
              min={-100}
              max={100}
              onChange={(contrast) => setPage({ contrast })}
            />
            {page.profile !== "color" && (
              <Slider
                label="Clean up"
                value={page.cleanup}
                min={0}
                max={100}
                onChange={(cleanup) => setPage({ cleanup })}
              />
            )}
            {page.profile === "bw" && (
              <Slider
                label="Threshold"
                value={page.threshold}
                min={-100}
                max={100}
                onChange={(threshold) => setPage({ threshold })}
              />
            )}
            {scan.pages.length > 1 && (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={applyToAll}
              >
                Apply to all pages
              </Button>
            )}
          </section>
          <section aria-label="PDF">
            <h3>PDF</h3>
            <label className="scan-field" htmlFor={titleId}>
              <span>Title</span>
              <Input
                id={titleId}
                value={scan.title ?? ""}
                placeholder="Scan"
                onChange={(e) =>
                  change({ ...scan, title: e.currentTarget.value })
                }
              />
            </label>
            <div className="scan-field">
              <span>Page size</span>
              <SegmentedControl
                aria-label="Page size"
                size="sm"
                full
                value={scan.pdf.size}
                onValueChange={(size: PageSize) =>
                  change({ ...scan, pdf: { ...scan.pdf, size } })
                }
                options={[
                  { value: "a4", label: "A4" },
                  { value: "letter", label: "Letter" },
                  { value: "fit", label: "Fit page" },
                ]}
              />
            </div>
            <div className="scan-field">
              <span>Margin</span>
              <SegmentedControl
                aria-label="Margin"
                size="sm"
                full
                value={String(scan.pdf.margin)}
                onValueChange={(margin: string) =>
                  change({
                    ...scan,
                    pdf: { ...scan.pdf, margin: Number(margin) },
                  })
                }
                options={PDF_MARGINS.map((m) => ({
                  value: String(m),
                  label: m ? `${m} mm` : "None",
                }))}
              />
            </div>
            <div className="scan-field">
              <span>Quality</span>
              <SegmentedControl
                aria-label="Quality"
                size="sm"
                full
                value={scan.pdf.quality}
                onValueChange={(quality: PdfQuality) =>
                  change({ ...scan, pdf: { ...scan.pdf, quality } })
                }
                options={[
                  { value: "small", label: "Small" },
                  { value: "standard", label: "Standard" },
                  { value: "high", label: "High" },
                ]}
              />
            </div>
          </section>
        </div>
      </div>
    );
  },
);

ScanEditor.displayName = "ScanEditor";
