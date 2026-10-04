"use client";

import { useState } from "react";
import { isVisible } from "@/lib/config/editing";
import { moduleLabel } from "@/lib/config/labels";
import type { ModuleConfig } from "@/lib/config/types";
import { ArrowDownIcon, ArrowUpIcon, Card, GripIcon, Toggle } from "../ui";

const arrowButton =
  "grid size-9 place-items-center rounded-admin text-ink-900 disabled:cursor-not-allowed disabled:text-ink-300";

/**
 * Order and visibility of the home modules of one segment. Reordering works
 * by dragging the handle or with the arrow buttons, so it never depends on a
 * pointer.
 */
export function ModulesCard({
  modules,
  onMove,
  onVisibilityChange,
}: {
  modules: ModuleConfig[];
  onMove: (from: number, to: number) => void;
  onVisibilityChange: (moduleId: string, visible: boolean) => void;
}) {
  const [dragged, setDragged] = useState<number | null>(null);
  const last = modules.length - 1;

  return (
    <Card title="Módulos del inicio">
      <ol className="divide-y divide-line">
        {modules.map((item, index) => {
          const name = moduleLabel(item.type);
          return (
            <li
              key={item.id}
              onDragOver={(event) => {
                if (dragged !== null) event.preventDefault();
              }}
              onDrop={() => {
                if (dragged !== null) onMove(dragged, index);
                setDragged(null);
              }}
              className={`flex items-center gap-3 py-2 ${dragged === index ? "opacity-50" : ""}`}
            >
              <span
                draggable
                aria-hidden
                onDragStart={() => setDragged(index)}
                onDragEnd={() => setDragged(null)}
                className="cursor-grab text-secondary"
              >
                <GripIcon />
              </span>
              <span className="flex-1 text-body">{name}</span>
              <button
                type="button"
                aria-label={`Subir ${name}`}
                disabled={index === 0}
                onClick={() => onMove(index, index - 1)}
                className={arrowButton}
              >
                <ArrowUpIcon />
              </button>
              <button
                type="button"
                aria-label={`Bajar ${name}`}
                disabled={index === last}
                onClick={() => onMove(index, index + 1)}
                className={arrowButton}
              >
                <ArrowDownIcon />
              </button>
              <Toggle
                label={`Mostrar ${name}`}
                checked={isVisible(item)}
                onChange={(visible) => onVisibilityChange(item.id, visible)}
              />
            </li>
          );
        })}
      </ol>
      <p className="mt-3 text-caption text-secondary">
        Arrastra para ordenar o usa las flechas. Los interruptores controlan la
        visibilidad.
      </p>
    </Card>
  );
}
