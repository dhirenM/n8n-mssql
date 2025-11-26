const crypto = require('crypto');

const RANDOM_BYTES = Buffer.from('53616c7465645f5f', 'hex');

function getKeyAndIv(salt, encryptionKey) {
	const password = Buffer.concat([Buffer.from(encryptionKey, 'binary'), salt]);
	const hash1 = crypto.createHash('md5').update(password).digest();
	const hash2 = crypto.createHash('md5')
		.update(Buffer.concat([hash1, password]))
		.digest();
	const iv = crypto.createHash('md5')
		.update(Buffer.concat([hash2, password]))
		.digest();
	const key = Buffer.concat([hash1, hash2]);
	return [key, iv];
}

function decrypt(data, encryptionKey) {
	const input = Buffer.from(data, 'base64');
	if (input.length < 16) return '';
	const salt = input.subarray(8, 16);
	const [key, iv] = getKeyAndIv(salt, encryptionKey);
	const contents = input.subarray(16);
	const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
	return Buffer.concat([decipher.update(contents), decipher.final()]).toString('utf-8');
}

// The encrypted value from the database (WITH "…" in the middle)
const encryptedFromDB = `U2FsdGVkX1+oVVa0SpUVvnT+4G85vBNc9t99sgreg9TJ3xo/Gx1zZlML9+sKxEcswA7O7LbWdVZNPSiXbpXKkdclQ7ehiveEqC3wN4KmLb/5hDYrIIVnJ+yf5NuLXRmpIy6AVC3lA+dFj+rC1Ib4zZEVX23aAw61J9ai124Ee85T3phv761fPLQRNr35en+oX9HwOOKMEa+OXp3LhJRZPb8Z0xHuD+8OkOj0OH7TWJem9wO5ryu+HR3PVaH/gEvwkQj3qZtS4yDudvleKt1ei+2IQm7nzqymFIREg8I7IxZ1oWu8Y+BWfPzUQMxYbMHmTtLRAOR3FLLdVhTs8NkXtEJLQ3YjkMhvImZwQ/U9O6ACN0tJLzfM5Fsh2UpTrsQD8csUnkEqjs9MGLxLHKRlFRc4vLHQC+BRpl2dgtIwZ4W06N/o/otSNsByPysQ/hJFmJaIaVqOE41gmtqPE/ECCNN1uDL9edyRW/FcuMDOOykw3CK8MEX…7tCeMH0jljTQHhtdpnuzwKNnDj7pAxgPvO4h2o0y+P9wReUdpCX3fkobsEHq+TdTvG2yMLm8E62N2U/y9HLp6/RNcvkiU8rWNk371t5BX7M5skdjl0njHYO6ELMGZRdcwlD8UWrf7zWaPNHASFhWHp0DM0fVbHVayBpymLRt85CXOZqaAKmLpJa886qluUTqaehVL41qyVPno+9S2woUWEI1Rba93HgP2x3YAhbsNOx+2JcYJYUdAf34+nHXIUAHcYHpra5/0lA5Y/zVuTg+yXvSeMsZZmcc8ssv5s+JeqFxiJYBb5F4cUuZZ0fcXZZyUoL3DGzPImDZvYTNemd4+fgs96hyU0VkYQW/dpyUd4F4i89G1jAU6fXfadmO25YE7TKjxA5lzO20hR4zpLauFFjeQTsuQl7UyZjXasTBKkrfYZ+TY30L9vf1PM84zTtiw7oNMI2glVPtCwWTioc0b+tB7gwKMtOoWNjAZJi9CBScafoA==`;

console.log("=".repeat(80));
console.log("ANALYZING ENCRYPTED DATA FROM DATABASE");
console.log("=".repeat(80));
console.log();
console.log("Encrypted string length:", encryptedFromDB.length);
console.log();

// Check if the encrypted string contains the ellipsis character
if (encryptedFromDB.includes('…')) {
    console.log("❌ PROBLEM FOUND!");
    console.log("The encrypted string contains '…' (Unicode U+2026)");
    console.log();
    console.log("Position of '…':", encryptedFromDB.indexOf('…'));
    console.log();
    console.log("Characters around '…':");
    const pos = encryptedFromDB.indexOf('…');
    console.log("Before:", encryptedFromDB.substring(pos - 20, pos));
    console.log("After:", encryptedFromDB.substring(pos + 1, pos + 21));
    console.log();
    console.log("This means the encrypted data was TRUNCATED during SAVE!");
    console.log("The '…' is in the encrypted base64 string itself, not in the original data.");
    console.log();
    console.log("=".repeat(80));
    console.log("ROOT CAUSE:");
    console.log("=".repeat(80));
    console.log("The credentials.repository.ts update() method is still truncating");
    console.log("during the SQL Server save, even though we added NVARCHAR(MAX) casting!");
    console.log();
    console.log("The issue is that the encrypted data is being truncated when");
    console.log("it's being passed to SQL Server as a parameter.");
} else {
    console.log("✅ No '…' found in encrypted string");
    console.log("Encrypted data appears complete");
}

console.log();
console.log("=".repeat(80));

// Try to decrypt it anyway (will likely fail due to bad base64)
console.log("Attempting to decrypt...");
try {
    const decrypted = decrypt(encryptedFromDB, "test-encryption-key-12345");
    console.log("Decrypted successfully (unexpected!)");
    console.log("Decrypted data:", decrypted.substring(0, 200));
} catch (error) {
    console.log("❌ Decryption failed (expected due to truncated base64)");
    console.log("Error:", error.message);
}

console.log();
console.log("=".repeat(80));

