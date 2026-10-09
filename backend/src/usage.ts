export interface UsageStore {
  getCount(installId: string, day: string): Promise<number>;
  getGlobalCount(day: string): Promise<number>;
  increment(installId: string, day: string): Promise<void>;
}

export class D1UsageStore implements UsageStore {
  constructor(private readonly db: D1Database) {}

  async getCount(installId: string, day: string): Promise<number> {
    const row = await this.db
      .prepare("SELECT count FROM usage WHERE install_id = ? AND day = ?")
      .bind(installId, day)
      .first<{ count: number }>();
    return Number(row?.count ?? 0);
  }

  async getGlobalCount(day: string): Promise<number> {
    const row = await this.db
      .prepare("SELECT COALESCE(SUM(count), 0) AS total FROM usage WHERE day = ?")
      .bind(day)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  async increment(installId: string, day: string): Promise<void> {
    await this.db
      .prepare(
        "INSERT INTO usage (install_id, day, count) VALUES (?, ?, 1) " +
          "ON CONFLICT(install_id, day) DO UPDATE SET count = count + 1",
      )
      .bind(installId, day)
      .run();
  }
}

export class MemoryUsageStore implements UsageStore {
  private counts = new Map<string, number>();

  async getCount(installId: string, day: string): Promise<number> {
    return this.counts.get(`${installId}|${day}`) ?? 0;
  }

  async getGlobalCount(day: string): Promise<number> {
    let total = 0;
    for (const [key, n] of this.counts) if (key.endsWith(`|${day}`)) total += n;
    return total;
  }

  async increment(installId: string, day: string): Promise<void> {
    const key = `${installId}|${day}`;
    this.counts.set(key, (this.counts.get(key) ?? 0) + 1);
  }
}
