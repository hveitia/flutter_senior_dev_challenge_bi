import designTokens from "../../../../packages/design_system/tokens/tokens.json";

const VARIABLE_PREFIX = "--ds-";

// Token groups whose values are CSS values. Everything else in the file
// (frames, prose notes, motion descriptions) is not styling for this console.
const STYLE_GROUPS = [
  "brand",
  "ink",
  "text",
  "border",
  "surface",
  "success",
  "danger",
  "warning",
  "info",
  "radius",
  "size",
  "space",
  "focus",
  "color",
  "shadow",
] as const;

const REFERENCE = /^\{(.+)\}$/;

export function cssVariableName(token: string): string {
  return `${VARIABLE_PREFIX}${token.replaceAll("/", "-")}`;
}

function isStyleToken(token: string): boolean {
  const group = token.split("/")[0];
  return STYLE_GROUPS.some((candidate) => candidate === group);
}

function isTypeToken(
  token: string,
  value: unknown,
): value is { size: number; height: number } {
  if (!token.startsWith("type/")) return false;
  if (typeof value !== "object" || value === null) return false;
  const { size, height } = value as Record<string, unknown>;
  return typeof size === "number" && typeof height === "number";
}

/** Declarations for the tokens that are CSS values, in file order. */
export function toCssVariables(tokens: Record<string, unknown>): string {
  let css = "";
  for (const [token, value] of Object.entries(tokens)) {
    if (isTypeToken(token, value)) {
      css += `${cssVariableName(token)}-size:${value.size}px;`;
      css += `${cssVariableName(token)}-height:${value.height}px;`;
      continue;
    }
    if (typeof value !== "string" || !isStyleToken(token)) continue;
    const reference = REFERENCE.exec(value);
    const resolved = reference?.[1]
      ? `var(${cssVariableName(reference[1])})`
      : value;
    css += `${cssVariableName(token)}:${resolved};`;
  }
  return css;
}

/** The design system tokens as custom properties, for the document root. */
export const themeCss = `:root{${toCssVariables(designTokens)}}`;
