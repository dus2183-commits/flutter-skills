(function (root) {
    class ImageLoader {

        static async fetchImageBlob(url, key,cache) {
            const arrayBuffer = await ImageLoader.fetchImageArrayBuffer(url, key,cache);
            return new Blob([arrayBuffer]);
        }

        static async fetchImageArrayBuffer(url, key,cache) {
            try {
                const cacheKey = ImageLoader.cacheKey(new URL(url).pathname);
                if (cache) {
                    const cacheRow = await DbUtil.getItem(cacheKey, "image");
                    if (cacheRow?.data) return cacheRow.data;
                }
                const arrayBuffer = await ImageLoader._fetchArrayBuffer(url,key);
                if(cache){
                    await DbUtil.putItem({ id:cacheKey, data: arrayBuffer }, "image");
                }
                return arrayBuffer;
            }catch (e){
                return new ArrayBuffer(0);
            }
        }

        // 1) HttpGet
        static _fetchArrayBuffer(url, key) {
            return new Promise((resolve, reject) => {
                const xhr = new XMLHttpRequest();
                xhr.open("GET", url, true);
                xhr.responseType = "arraybuffer";
                xhr.onload = () => {
                    const status = xhr.status;
                    const accepted = status >= 200 && status < 300;
                    const fileUri = status === 0;
                    const notModified = status === 304;
                    const unknownRedirect = status > 307 && status < 400;
                    const success = accepted || fileUri || notModified || unknownRedirect;
                    if (success){
                        // const v1=ImageLoader.decryptEcbPkcs7(xhr.response, key);
                        // resolve(v1)

                        const ASM = root.asmCrypto || root.asmcryptoMin;
                        const uint8Array = new Uint8Array(xhr.response);        // ArrayBuffer -> Uint8Array
                        const aeskey  = new TextEncoder().encode(key);       // string -> Uint8Array (UTF-8 bytes)
                        const v2 = ASM.AES_ECB.decrypt(uint8Array, aeskey,true);
                        resolve(v2.buffer)
                    }else{
                        reject(new Error("HTTP " + status));
                    }
                };
                xhr.onerror = () => reject(new Error("Network error"));
                xhr.send();

                // fetch(url)
                //     .then((resp) => {
                //         const status = resp.status;
                //         const accepted = status >= 200 && status < 300;
                //         const fileUri = status === 0;
                //         const notModified = status === 304;
                //         const unknownRedirect = status > 307 && status < 400;
                //         const success = accepted || fileUri || notModified || unknownRedirect;
                //         if (!success) throw new Error("HTTP " + status);
                //         return resp.arrayBuffer();
                //     })
                //     .then((buf) => resolve(TextLoader.decryptEcbPkcs7(buf, key)))
                //     .catch(reject);
            });
        }


        static decryptEcbPkcs7(cipherBuf, key) {
            // const wordArrayV1 = ImageLoader.arrayBufferToWordArrayV1(cipherBuf);
            // const wordArrayV2 = ImageLoader.arrayBufferToWordArrayV2(cipherBuf);
            const wordArray = ImageLoader.arrayBufferToWordArrayV2(cipherBuf);
            const aeskey = CryptoJS.enc.Utf8.parse(key);

            const decrypted = CryptoJS.AES.decrypt(
                { ciphertext: wordArray },
                aeskey,
                { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }
            );

//            const v1 = ImageLoader.wordArrayToArrayBufferV1(decrypted);
//            const v2 = ImageLoader.wordArrayToArrayBufferV2(decrypted);
            return ImageLoader.wordArrayToArrayBufferV2(decrypted);
        }

        // ArrayBuffer -> CryptoJS WordArray
        static arrayBufferToWordArrayV1(buf) {
            // // --- START probe ---
            // const t0 = nowMs();
            // const m0 = heapUsedBytes();

            const u8 = new Uint8Array(buf);
            const words = [];
            for (let i = 0; i < u8.length; i += 4) {
                words.push(
                    ((u8[i] << 24) |
                        ((u8[i + 1] || 0) << 16) |
                        ((u8[i + 2] || 0) << 8) |
                        (u8[i + 3] || 0)) >>> 0
                );
            }

            const wordArray = CryptoJS.lib.WordArray.create(words, u8.length);

            // // --- END probe ---
            // const t1 = nowMs();
            // const m1 = heapUsedBytes();
            // logSpan("[arrayBufferToWordArrayV1] inside", t0, t1, m0, m1);

            return wordArray
        }

        // ArrayBuffer -> CryptoJS WordArray
        static arrayBufferToWordArrayV2(buf) {
            // // --- START probe ---
            // const t0 = nowMs();
            // const m0 = heapUsedBytes();

            const u8 = new Uint8Array(buf);
            const len = u8.length;
            const nWords = (len + 3) >>> 2;
            const words = new Array(nWords);

            // 不用 push，直接填
            for (let j = 0, i = 0; j < nWords; j++, i += 4) {
                words[j] = ((u8[i] << 24) | (u8[i + 1] << 16) | (u8[i + 2] << 8) | (u8[i + 3])) >>> 0;
            }
            const wordArray= CryptoJS.lib.WordArray.create(words, len);

            // // --- END probe ---
            // const t1 = nowMs();
            // const m1 = heapUsedBytes();
            // logSpan("[arrayBufferToWordArrayV2] inside", t0, t1, m0, m1);
            return wordArray
        }


        // CryptoJS WordArray -> ArrayBuffer
        static wordArrayToArrayBufferV1(wordArray) {
//            // // --- START probe ---
//            const t0 = nowMs();
//            const m0 = heapUsedBytes();


            const words = wordArray.words;
            const sigBytes = wordArray.sigBytes;
            const u8 = new Uint8Array(sigBytes);
            for (let i = 0; i < sigBytes; i++) {
                const w = words[(i / 4) | 0];
                u8[i] = (w >>> (24 - (i % 4) * 8)) & 0xff;
            }

//            // // --- END probe ---
//            const t1 = nowMs();
//            const m1 = heapUsedBytes();
//            logSpan("[wordArrayToArrayBufferV1] inside", t0, t1, m0, m1);

            return u8.buffer;
        }


        // CryptoJS WordArray -> ArrayBuffer
        static wordArrayToArrayBufferV2(wordArray) {
//            // // --- START probe ---
//            const t0 = nowMs();
//            const m0 = heapUsedBytes();


            const { words, sigBytes } = wordArray;
            const buf = new ArrayBuffer(sigBytes);
            const dv = new DataView(buf);
            const fullWords = (sigBytes / 4) | 0;
            let offset = 0;

            for (let i = 0; i < fullWords; i++, offset += 4) {
                dv.setUint32(offset, words[i], false);
            }

            // 处理尾部不足 4 字节
            const rem = sigBytes - offset;
            if (rem) {
                const w = words[fullWords];
                for (let k = 0; k < rem; k++) {
                    dv.setUint8(offset + k, (w >>> (24 - k * 8)) & 0xff);
                }
            }
//            // // --- END probe ---
//            const t1 = nowMs();
//            const m1 = heapUsedBytes();
//            logSpan("[wordArrayToArrayBufferV2] inside", t0, t1, m0, m1);
            return buf;
        }

        static cacheKey(str) {
            // return  CryptoJS.MD5(str).toString().toUpperCase();

            let h = 0xcbf29ce484222325n;
            const prime = 0x100000001b3n;
            for (let i = 0; i < str.length; i++) {
                h ^= BigInt(str.charCodeAt(i));
                h = (h * prime) & 0xffffffffffffffffn;
            }
            return h.toString(16).padStart(16, "0").toUpperCase(); // 16位hex
        }
    }

    // ====== 计时/计内存工具（浏览器 + Node 兼容）======
    function nowMs() {
        // Browser
        if (typeof performance !== "undefined" && performance.now) return performance.now();
        // Node fallback
        const [s, ns] = process.hrtime();
        return s * 1000 + ns / 1e6;
    }

    function heapUsedBytes() {
        if (typeof performance !== "undefined" && performance.memory && typeof performance.memory.usedJSHeapSize === "number") {
            return performance.memory.usedJSHeapSize;
        }
        return null; // 不支持
    }

    function fmtBytes(n) {
        if (n == null) return "N/A";
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        let v = n;
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
        return `${v.toFixed(2)} ${units[i]}`;
    }

    function logSpan(label, t0, t1, m0, m1) {
        const dt = (t1 - t0).toFixed(3);
        const dm = (m0 == null || m1 == null) ? "N/A" : fmtBytes(m1 - m0);
        console.log(`${label}  time: ${dt} ms,  heapΔ: ${dm}`);
    }

    // 挂到 window / self，方便主线程和 SW 调用
    root.ImageLoader = ImageLoader;
})(typeof self !== "undefined" ? self : window);
