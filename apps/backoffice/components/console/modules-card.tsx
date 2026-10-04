"use client";

import { useEffect, useRef, useState } from "react";
import { isVisible } from "@/lib/config/editing";
import { moduleLabel } from "@/lib/config/labels";
import type { ModuleConfig } from "@/lib/config/types";
import { ArrowDownIcon, ArrowUpIcon, Card, GripIcon, Toggle } from "../ui";

type Direction = "up" | "down";

function arrowKey(id: string, direction: Direction): string {
  return `${id}:${direction}`;
}

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

  // A reorder moves the row in the document, which can drop keyboard focus.
  // Focus goes back to the arrow that was used, or to the opposite one when
  // the module reached an end and that arrow became disabled.
  const arrows = useRef(new Map<string, HTMLButtonElement>());
  const refocus = useRef<{ id: string; direction: Direction } | null>(null);
  useEffect(() => {
    const wanted = refocus.current;
    if (!wanted) return;
    refocus.current = null;
    const used = arrows.current.get(arrowKey(wanted.id, wanted.direction));
    const opposite = arrows.current.get(
      arrowKey(wanted.id, wanted.direction === "up" ? "down" : "up"),
    );
    (used && !used.disabled ? used : opposite)?.focus();
  }, [modules]);

  const register = (id: string, direction: Direction) => (node: HTMLButtonElement | null) => {
    const key = arrowKey(id, direction);
    if (node) arrows.current.set(key, node);
    else arrows.current.delete(key);
  };

  const moveWithArrow = (id: string, index: number, direction: Direction) => {
    refocus.current = { id, direction };
    onMove(index, direction === "up" ? index - 1 : index + 1);
  };

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
                ref={register(item.id, "up")}
                onClick={() => moveWithArrow(item.id, index, "up")}
                className={arrowButton}
              >
                <ArrowUpIcon />
              </button>
              <button
                type="button"
                aria-label={`Bajar ${name}`}
                disabled={index === last}
                ref={register(item.id, "down")}
                onClick={() => moveWithArrow(item.id, index, "down")}
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
