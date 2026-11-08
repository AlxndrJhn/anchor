"use client";

import { RadioCards } from "@/components/ui/radio-cards";
import { SegmentedControl } from "@/components/ui/segmented-control";
import {
  type DateDisplay,
  formatFullDate,
  formatTime,
  type TimeDisplay,
  usePreferencesStore,
  type WeekStart,
} from "@/features/preferences";
import { Row, RowText, Section } from "./settings-blocks";

// Named too, as 11/08 and 08/11 can't be told apart by the date alone.
const CHOSEN_DATE_FORMATS: {
  value: Exclude<DateDisplay, "auto">;
  order: string;
}[] = [
  { value: "mdy", order: "Month first" },
  { value: "dmy", order: "Day first" },
  { value: "mdy-slash", order: "Month first" },
  { value: "dmy-slash", order: "Day first" },
  { value: "dmy-dot", order: "Day first" },
  { value: "iso", order: "Year first" },
];

export function DateTimeSection() {
  const dateDisplay = usePreferencesStore((s) => s.ui.dateDisplay ?? "auto");
  const timeDisplay = usePreferencesStore((s) => s.ui.timeDisplay ?? "auto");
  const weekStart = usePreferencesStore((s) => s.ui.weekStart ?? "auto");
  const setUI = usePreferencesStore((s) => s.setUIPreference);
  const today = new Date();
  // An afternoon, so the two clocks read differently.
  const sampleTime = new Date(2026, 0, 1, 16, 30);
  return (
    <Section id="date-time" title="Date and time">
      <Row className="grid items-start gap-3.5">
        <RowText
          title="Date format"
          text="How dates read across Anchor+. On this device only."
        />
        <RadioCards<DateDisplay>
          aria-label="Date format"
          value={dateDisplay}
          onValueChange={(value) => setUI("dateDisplay", value)}
          className="grid-cols-3 max-md:grid-cols-2"
          options={[
            {
              value: "auto",
              label: "Automatic",
              description: formatFullDate(today, "auto"),
            },
            ...CHOSEN_DATE_FORMATS.map(({ value, order }) => ({
              value,
              label: formatFullDate(today, value),
              description: order,
            })),
          ]}
        />
      </Row>
      <Row>
        <RowText
          title="Time format"
          text={`Times read like ${formatTime(sampleTime, timeDisplay)}. Automatic follows your browser's language. On this device only.`}
        />
        <SegmentedControl<TimeDisplay>
          aria-label="Time format"
          size="sm"
          value={timeDisplay}
          onValueChange={(value) => setUI("timeDisplay", value)}
          options={[
            { value: "auto", label: "Automatic" },
            { value: "12h", label: "12-hour" },
            { value: "24h", label: "24-hour" },
          ]}
        />
      </Row>
      <Row>
        <RowText
          title="First day of the week"
          text="Where the week starts in the calendar. Automatic follows your browser's language. On this device only."
        />
        <SegmentedControl<WeekStart>
          aria-label="First day of the week"
          size="sm"
          value={weekStart}
          onValueChange={(value) => setUI("weekStart", value)}
          options={[
            { value: "auto", label: "Automatic" },
            { value: "monday", label: "Mon" },
            { value: "saturday", label: "Sat" },
            { value: "sunday", label: "Sun" },
          ]}
        />
      </Row>
    </Section>
  );
}
