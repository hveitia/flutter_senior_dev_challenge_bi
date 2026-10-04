import { describe, expect, it } from "vitest";
import { offlineMessaging } from "./offline-messaging";

describe("offlineMessaging", () => {
  it("accepts a send to a topic without reaching any service", async () => {
    const id = await offlineMessaging().send({ topic: "segment-family" }, true);

    expect(id).toMatch(/^local-/);
  });

  it("answers for every device of a send to several, with none unregistered", async () => {
    const response = await offlineMessaging().sendEachForMulticast(
      { tokens: ["a", "b", "c"] },
      true,
    );

    expect(response.successCount).toBe(3);
    expect(response.failureCount).toBe(0);
    expect(response.responses).toHaveLength(3);
    expect(response.responses.every((each) => each.success && !each.error)).toBe(true);
  });

  it("refuses to stand in for a real delivery", async () => {
    await expect(offlineMessaging().send({ topic: "segment-family" }, false)).rejects.toThrow(
      /dry run/,
    );
    await expect(
      offlineMessaging().sendEachForMulticast({ tokens: ["a"] }, false),
    ).rejects.toThrow(/dry run/);
  });
});
