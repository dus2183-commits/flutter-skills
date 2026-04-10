(function (root) {
    if (root.DbUtil) {
        // 已经初始化过，直接返回
        return;
    }

    /**
     * DbUtil - 基于 Dexie 的 IndexedDB 工具封装
     *
     * 设计原则：
     * - openStore() 在打开失败时不会抛出，而是返回 false 并设置 openFailed 标记
     * - 所有外部方法在失败时返回 false（而不是抛异常）
     * - 成功时返回原本应有的值（如 put 返回主键，get 返回记录，cleanupExpired 返回删除数）
     *
     * 依赖: Dexie (确保页面已引入 Dexie)
     */
    class DbUtil {
        static dbName = "database";

        // 打开失败标志（用于避免重复无意义重试）
        static openFailed = false;

        // 静态初始化数据库 (支持多 store)
        static db = (() => {
            const db = new Dexie(DbUtil.dbName);
            db.version(260126).stores({
                image: "id, updated_at",
                text: "id, updated_at",
            });
            return db;
        })();

        /**
         * 打开数据库
         * @returns {Promise<boolean>} 成功返回 true，失败返回 false（并设置 openFailed）
         */
        static async openStore() {
            if (DbUtil.openFailed) {
                // 之前已经失败过，快速返回 false，避免无限重试
                return false;
            }

            if (DbUtil.db.isOpen()) {
                return true;
            }

            try {
                await DbUtil.db.open();
                return true;
            } catch (err) {
                // 标记打开失败，记录错误
                DbUtil.openFailed = true;
                console.error("[DbUtil] db.open() failed:", err);
                return false;
            }
        }

        /**
         * putItem - 新增/修改数据 (需指定 storeName)
         * 失败时返回 false，成功时返回 Dexie 返回的主键
         */
        static async putItem(data, storeName) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return false;

                const record = {
                    ...(data || {}),
                    updated_at: Math.floor(Date.now() / 1000),
                };
                // put 返回主键
                const res = await DbUtil.db.table(storeName).put(record);
                return res;
            } catch (err) {
                console.error("[DbUtil] putItem error:", err);
                return false;
            }
        }

        /**
         * deleteItem - 删除数据 (需指定 storeName)
         * 成功返回 true，失败返回 false
         */
        static async deleteItem(id, storeName) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return false;

                await DbUtil.db.table(storeName).delete(id);
                return true;
            } catch (err) {
                console.error("[DbUtil] deleteItem error:", err);
                return false;
            }
        }

        /**
         * getItem - 查询单条数据 (需指定 storeName)
         * 成功返回记录（如果不存在返回 undefined），失败返回 false
         */
        static async getItem(id, storeName) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return false;

                const res = await DbUtil.db.table(storeName).get(id);
                return res;
            } catch (err) {
                console.error("[DbUtil] getItem error:", err);
                return false;
            }
        }

        /**
         * getStoreSize - 获取指定 store 的所有数据总大小 (字节)
         * 成功返回大小（整数），失败返回 0
         */
        static async getStoreSize(storeName) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return 0;

                let totalSize = 0;
                await DbUtil.db.table(storeName).each((item) => {
                    if (item && item.data && item.data.byteLength) {
                        totalSize += item.data.byteLength;
                    } else if (item && item.data && item.data.length) {
                        // For strings or simple arrays
                        totalSize += item.data.length;
                    }
                });
                return totalSize;
            } catch (err) {
                console.error("[DbUtil] getStoreSize error:", err);
                return 0;
            }
        }
        static async getAllItems(storeName) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return false;

                const res = await DbUtil.db.table(storeName).toArray();
                return res;
            } catch (err) {
                console.error("[DbUtil] getAllItems error:", err);
                return false;
            }
        }

        /**
         * clearStore - 清空 store (需指定 storeName)
         * 成功返回 true，失败返回 false
         */
        static async clearStore(storeName) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return false;

                await DbUtil.db.table(storeName).clear();
                return true;
            } catch (err) {
                console.error("[DbUtil] clearStore error:", err);
                return false;
            }
        }

        // 可选：关闭数据库（不会抛）
        static close() {
            try {
                if (DbUtil.db.isOpen()) DbUtil.db.close();
            } catch (err) {
                console.warn("[DbUtil] close error:", err);
            }
        }

        /**
         * cleanupExpired - 分批清理过期数据（默认清理 7 天前）
         * - 适合 10w+ 数据量，避免一次性 delete 卡死/超时
         * - 返回删除条数，失败返回 false
         */
        static async cleanupExpired(storeName, days = 7, batchSize = 1000) {
            try {
                const ok = await DbUtil.openStore();
                if (!ok) return false;

                const expireAt = Math.floor(Date.now() / 1000) - days * 24 * 60 * 60;
                const table = DbUtil.db.table(storeName);
                let totalDeleted = 0;
                while (true) {
                    const keys = await table
                        .where("updated_at")
                        .below(expireAt)
                        .limit(batchSize)
                        .primaryKeys();
                    if (!keys || keys.length === 0) break;
                    await table.bulkDelete(keys);
                    totalDeleted += keys.length;
                }
                return totalDeleted;
            } catch (err) {
                console.error("[DbUtil] cleanupExpired error:", err);
                return false;
            }
        }
    }

    root.DbUtil = DbUtil;
})(typeof self !== "undefined" ? self : window);
