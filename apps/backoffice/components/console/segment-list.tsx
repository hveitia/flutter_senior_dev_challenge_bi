import type { SegmentConfig } from "@/lib/config/types";
import { CheckIcon } from "../ui";

const COUNT = new Intl.NumberFormat("en-US");

function customersLabel(count: number): string {
  return count === 1 ? "1 cliente" : `${COUNT.format(count)} clientes`;
}

export function SegmentList({
  segments,
  selected,
  customers,
  note,
  onSelect,
}: {
  segments: Record<string, SegmentConfig>;
  selected: string;
  /** Registered customers per segment; a segment missing here shows no count. */
  customers: Record<string, number>;
  /** What choosing a segment means in the section that is open. */
  note: string;
  onSelect: (segmentId: string) => void;
}) {
  return (
    <nav aria-label="Segmentos" className="rounded-admin border border-line bg-surface-0 p-3">
      <h2 className="px-3 py-2 text-body font-semibold">Segmentos</h2>
      {/* A column beside the content on wide screens, a row above it otherwise. */}
      <ul className="flex flex-wrap gap-1 xl:block">
        {Object.entries(segments).map(([segmentId, segment]) => {
          const isSelected = segmentId === selected;
          const count = customers[segmentId];
          return (
            <li key={segmentId}>
              <button
                type="button"
                aria-current={isSelected ? "true" : undefined}
                onClick={() => onSelect(segmentId)}
                className={`flex w-full items-center justify-between gap-3 rounded-admin px-3 py-2 text-left ${
                  isSelected ? "bg-brand-50" : ""
                }`}
              >
                <span>
                  <span className={`block text-body ${isSelected ? "font-semibold" : ""}`}>
                    {segment.label}
                  </span>
                  {count === undefined ? null : (
                    <span className="block text-caption text-secondary">
                      {customersLabel(count)}
                    </span>
                  )}
                </span>
                {isSelected ? <CheckIcon /> : null}
              </button>
            </li>
          );
        })}
      </ul>
      <p className="px-3 py-2 text-caption text-secondary">{note}</p>
    </nav>
  );
}
