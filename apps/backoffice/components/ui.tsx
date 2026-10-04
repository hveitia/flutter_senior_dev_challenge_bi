import type { ComponentProps, ReactNode } from "react";

/** Small building blocks shared by the console's cards. */

export function Card({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-admin border border-line bg-surface-0 p-5">
      <h2 className="font-heading text-subtitle">{title}</h2>
      {description ? (
        <p className="mt-1 text-caption text-secondary">{description}</p>
      ) : null}
      <div className="mt-4">{children}</div>
    </section>
  );
}

/** An on/off setting. The state is announced, not only painted. */
export function Toggle({
  label,
  checked,
  onChange,
  disabled = false,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`relative h-6 w-11 shrink-0 rounded-chip border transition-colors disabled:opacity-50 ${
        checked ? "border-brand-500 bg-brand-500" : "border-ink-300 bg-surface-2"
      }`}
    >
      <span
        aria-hidden
        className={`absolute top-0.5 size-[18px] rounded-chip bg-ink-900 transition-[left] ${
          checked ? "left-[22px]" : "left-0.5"
        }`}
      />
    </button>
  );
}

const fieldBox =
  "h-11 w-full rounded-admin border border-line bg-surface-0 px-3 text-body text-ink-900 placeholder:text-secondary disabled:bg-surface-2";

export function Field({
  label,
  htmlFor,
  error,
  children,
}: {
  label: string;
  htmlFor: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label htmlFor={htmlFor} className="mb-1 block text-caption font-semibold">
        {label}
      </label>
      {children}
      {error ? (
        <p role="alert" className="mt-1 flex items-center gap-1 text-caption text-danger-500">
          <AlertIcon />
          {error}
        </p>
      ) : null}
    </div>
  );
}

export function TextInput(props: ComponentProps<"input">) {
  return <input {...props} className={fieldBox} />;
}

export function TextArea(props: ComponentProps<"textarea">) {
  return <textarea {...props} className={`${fieldBox} h-auto py-2`} />;
}

export function Select(props: ComponentProps<"select">) {
  return <select {...props} className={fieldBox} />;
}

type ButtonVariant = "primary" | "secondary" | "text";

const buttonVariants: Record<ButtonVariant, string> = {
  // Dark ink on brand orange: white on this orange does not reach AA.
  primary: "bg-brand-500 text-ink-900 disabled:bg-surface-2 disabled:text-secondary",
  secondary: "border border-ink-900 text-ink-900 disabled:opacity-50",
  text: "text-brand-700 disabled:text-secondary",
};

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ComponentProps<"button"> & { variant?: ButtonVariant }) {
  return (
    <button
      type="button"
      {...props}
      className={`h-11 rounded-admin px-4 text-body font-semibold disabled:cursor-not-allowed ${buttonVariants[variant]} ${className}`}
    />
  );
}

function Icon({ children }: { children: ReactNode }) {
  return (
    <svg
      aria-hidden
      viewBox="0 0 24 24"
      className="size-4 shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {children}
    </svg>
  );
}

export const ArrowUpIcon = () => (
  <Icon>
    <path d="M12 19V5M6 11l6-6 6 6" />
  </Icon>
);

export const ArrowDownIcon = () => (
  <Icon>
    <path d="M12 5v14M6 13l6 6 6-6" />
  </Icon>
);

export const GripIcon = () => (
  <Icon>
    <path d="M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01" />
  </Icon>
);

export const CheckIcon = () => (
  <Icon>
    <path d="M5 12.5l4.5 4.5L19 7.5" />
  </Icon>
);

export const AlertIcon = () => (
  <Icon>
    <path d="M12 4l9 16H3l9-16zM12 10v4M12 17h.01" />
  </Icon>
);

export const InfoIcon = () => (
  <Icon>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 11v5M12 8h.01" />
  </Icon>
);

export const ClockIcon = () => (
  <Icon>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 7v5l3 2" />
  </Icon>
);
