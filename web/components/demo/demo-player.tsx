"use client";

import { MousePointer2, Play, RotateCcw, X } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { demoBySlug } from "@/lib/demo/demos";
import {
  caretToEnd,
  center,
  clickElement,
  findTarget,
  hoverElement,
  leaveElement,
  type Play as PlayContext,
  pressKey,
  type Step,
  Stopped,
  typeCharacter,
} from "@/lib/demo/runner";
import { useDemo } from "@/lib/demo/store";
import { cn } from "@/lib/utils";

const MOVE_MS = 650;

/**
 * Plays the feature demos over the app (see lib/demo): a pointer clicks
 * through the steps while a caption says what happens. Afterwards the notes
 * stay as the demo left them, to try out.
 */
export function DemoPlayer() {
  const router = useRouter();
  const { slug, status, caption, run, set } = useDemo();
  const [cursor, setCursor] = React.useState<{
    x: number;
    y: number;
    pressed: boolean;
  } | null>(null);
  const [isHidden, setIsHidden] = React.useState(false);
  const demo = slug ? demoBySlug(slug) : undefined;

  React.useEffect(() => {
    if (run === 0 || !slug) return;
    const playing = demoBySlug(slug);
    if (!playing) return;
    let stopped = false;
    setIsHidden(false);
    const check = () => {
      const state = useDemo.getState();
      if (stopped || state.run !== run || state.status !== "playing")
        throw new Stopped();
    };
    const pause = async (ms: number) => {
      await new Promise((resolve) => setTimeout(resolve, ms));
      check();
    };
    let position = {
      x: window.innerWidth / 2,
      y: window.innerHeight * 0.6,
    };
    setCursor({ ...position, pressed: false });
    let lastTarget: Element | null = null;
    const play: PlayContext = {
      check,
      pause,
      find: (target, timeout) => findTarget(target, check, timeout),
      moveTo: async (element) => {
        if (lastTarget && lastTarget !== element) leaveElement(lastTarget);
        lastTarget = element;
        element.scrollIntoView({ block: "nearest", inline: "nearest" });
        position = center(element);
        setCursor({ ...position, pressed: false });
        await pause(MOVE_MS);
      },
      say: (text) => set({ caption: text }),
      go: (path) => router.push(path),
      cursor: (x, y, pressed = false) => {
        position = { x, y };
        setCursor({ x, y, pressed });
      },
    };
    const press = async () => {
      setCursor({ ...position, pressed: true });
      await pause(140);
      setCursor({ ...position, pressed: false });
    };

    const perform = async (step: Step) => {
      if ("say" in step && step.say) play.say(step.say);
      if ("click" in step) {
        const element = await play.find(step.click);
        await play.moveTo(element);
        await press();
        clickElement(element);
        await pause(700);
      } else if ("hover" in step) {
        const element = await play.find(step.hover);
        await play.moveTo(element);
        hoverElement(element);
        await pause(600);
      } else if ("type" in step) {
        if (step.into) {
          const element = await play.find(step.into);
          await play.moveTo(element);
          await press();
          clickElement(element);
          caretToEnd(element);
          await pause(250);
        }
        for (const character of step.type) {
          typeCharacter(character);
          await pause(character === " " ? 90 : 55);
        }
        await pause(500);
      } else if ("key" in step) {
        pressKey(step.key, step);
        await pause(700);
      } else if ("go" in step) {
        play.go(step.go);
        await pause(1200);
      } else if ("wait" in step) {
        await pause(step.wait);
      } else if ("waitFor" in step) {
        await play.find(step.waitFor, 10_000);
      } else if ("run" in step) {
        await step.run(play);
        await pause(500);
      } else if ("say" in step) {
        await pause(Math.min(4500, 1400 + step.say.length * 38));
      }
    };

    void (async () => {
      try {
        router.replace(playing.start);
        await pause(1600);
        for (const step of playing.steps) await perform(step);
        set({ status: "done", caption: playing.outro });
      } catch (error) {
        if (error instanceof Stopped) return;
        console.warn("Demo stopped:", error);
        set({ status: "done", caption: playing.outro });
      } finally {
        if (lastTarget) leaveElement(lastTarget);
        if (!stopped) setCursor(null);
      }
    })();
    return () => {
      stopped = true;
    };
  }, [run, slug, router, set]);

  const isPlaying = status === "playing" || status === "loading";

  return (
    <div data-demo-player>
      {isPlaying && (
        // Holds the person's clicks while the demo plays.
        <div className="pointer-events-auto fixed inset-0 z-[2147483000]" />
      )}
      {cursor && isPlaying && (
        <div
          aria-hidden
          className="pointer-events-none fixed top-0 left-0 z-[2147483002] transition-transform ease-[cubic-bezier(.3,.7,.3,1)]"
          style={{
            transform: `translate(${cursor.x - 3}px, ${cursor.y - 2}px)`,
            transitionDuration: `${MOVE_MS - 100}ms`,
          }}
        >
          <MousePointer2
            className={cn(
              "size-7 fill-foreground stroke-background stroke-[1.5] drop-shadow-md transition-transform duration-100",
              cursor.pressed && "scale-75",
            )}
          />
          {cursor.pressed && (
            <span className="absolute -top-3 -left-3 size-8 animate-ping rounded-full bg-accent-strong/40" />
          )}
        </div>
      )}
      {demo && status !== "idle" && !isHidden && (
        <section
          aria-live="polite"
          aria-label="Feature demo"
          className="pointer-events-auto fixed bottom-4 left-1/2 z-[2147483001] grid w-[min(560px,calc(100vw-32px))] -translate-x-1/2 gap-2.5 rounded-xl bg-popover p-4 text-popover-foreground shadow-[0_0_0_1px_var(--border),var(--sh-lg,0_12px_32px_rgb(0_0_0/.25))]"
        >
          <div className="flex items-center gap-2">
            <span className="rounded-pill bg-accent-strong/15 px-2 py-0.5 font-semibold text-accent-ink text-small">
              {isPlaying ? "Demo playing" : "Your turn"}
            </span>
            <b className="min-w-0 flex-1 truncate font-semibold text-ui">
              {demo.title}
            </b>
            {!isPlaying && (
              <button
                type="button"
                aria-label="Close"
                onClick={() => setIsHidden(true)}
                className="grid size-7 cursor-pointer place-items-center rounded-md text-muted-foreground hover:bg-foreground/6"
              >
                <X className="size-4" />
              </button>
            )}
          </div>
          <p className="text-ui leading-snug">{caption}</p>
          <div className="flex flex-wrap items-center gap-2">
            {isPlaying ? (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => set({ status: "done", caption: demo.outro })}
              >
                Skip to trying it
              </Button>
            ) : (
              <>
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => router.push(`/${demo.slug}`)}
                >
                  <RotateCcw />
                  Play again
                </Button>
                <Button variant="quiet" size="sm" asChild>
                  <Link href="/settings#set-demos">
                    <Play />
                    All feature demos
                  </Link>
                </Button>
              </>
            )}
          </div>
        </section>
      )}
    </div>
  );
}
