const crypto = require('crypto');

// This mimics the Cipher class implementation
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

function encrypt(data, encryptionKey) {
	const salt = crypto.randomBytes(8);
	const [key, iv] = getKeyAndIv(salt, encryptionKey);
	const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
	
	// Convert to string if object, then to Buffer to ensure proper handling of large data
	const dataString = typeof data === 'string' ? data : JSON.stringify(data);
	const dataBuffer = Buffer.from(dataString, 'utf-8');
	
	// Process data in chunks to handle large data correctly
	// cipher.update() can handle large buffers, but we ensure all data is processed
	const encrypted = cipher.update(dataBuffer);
	const final = cipher.final();
	
	return Buffer.concat([RANDOM_BYTES, salt, encrypted, final]).toString('base64');
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

// Test with the JWT token
const jwtToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjdFRTlBREIzRTYyRjc3Q0NERDg1N0ZEOEZGRjAzQUNBQUUwNUNCMjlSUzI1NiIsIng1dCI6ImZ1bXRzLVl2ZDh6ZGhYX1lfX0E2eXE0Rnl5ayIsInR5cCI6ImF0K2p3dCJ9.eyJpc3MiOiJodHRwczovL3lhcmRpc2FsZXMueWFyZGlvbmVjb3JlcWEuY29tL3lBdXRoMi9pZGVudGl0eSIsIm5iZiI6MTc2MzYyNzgyMiwiaWF0IjoxNzYzNjI3ODIyLCJleHAiOjE3NjM2MzE0MjIsImF1ZCI6Imh0dHBzOi8veWFyZGlzYWxlcy55YXJkaW9uZWNvcmVxYS5jb20veUF1dGgyL2lkZW50aXR5L3Jlc291cmNlcyIsInNjb3BlIjpbIm9wZW5pZCIsInByb2ZpbGUiLCJlbWFpbCIsIm9mZmxpbmVfYWNjZXNzIl0sImFtciI6WyJleHRlcm5hbCJdLCJjbGllbnRfaWQiOiJ5YXJkaXNhbGVzX21jcCIsInN1YiI6IjU2NmNjYWY4LWNhZWMtNGFjZi1hMzRmLWQ2MDUyYTg1NWM4MiIsImF1dGhfdGltZSI6MTc2MzYyNzgxNiwiaWRwIjoieWFyZGlzYWxlc195YXJkaWF6dXJlIiwid2luYWNjb3VudG5hbWUiOiJEaGlyZW4uTWlzdHJ5QFlhcmRpLkNvbSIsInlOYW1lIjoiRGhpcmVuLk1pc3RyeUBZYXJkaS5Db20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJEaGlyZW4uTWlzdHJ5QFlhcmRpLkNvbSIsImVtYWlsIjoiRGhpcmVuLk1pc3RyeUBZYXJkaS5Db20iLCJlbWFpbF92ZXJpZmllZCI6ImZhbHNlIiwiZ2l2ZW5fbmFtZSI6IkRoaXJlbiIsImZhbWlseV9uYW1lIjoiTWlzdHJ5Iiwic2lkIjoiNkEzMzFCNUM2QTI0ODkxRDY2RTJCQTQxQ0VFNzMyRTcifQ.ddcdzvAbvBpwfynnM1xgYoLoW9HehgWd1En5tecFjoGKJu6X0Q9C1ufRPwV2NTMYYh3CN3SZ663-yIIofIh-kdWIeA-RmBe5GrCOibn9M_KZnr-AApWs2ooqWANxkJtX2ZXdKGelhSge4ri5h96iS7qqHymAkDEDgkMQ3xvAjlR_iPm51oT1-HQJFFbpmBsFDTpP_e1zca07lVdCvtFySzpsIuhwEELrA6uxi1WWH_MQdgYRTmkZ1tDl-MUova9IhCjDM48lZEo9wTaUUefqA_XuZlcCORZZzmRU_Q1DoLeMMgwBdYKj6EYarXhkfFIL3C64Vn7jhdsQtXCwqDdecg";

// Test with a credential object (as n8n does)
const credentialData = {
	token: jwtToken
};

console.log("=".repeat(80));
console.log("ENCRYPTION/DECRYPTION TEST");
console.log("=".repeat(80));
console.log();

console.log("Original JWT Token:");
console.log(jwtToken);
console.log();
console.log("Token length:", jwtToken.length, "characters");
console.log();

// Use a test encryption key (in n8n, this comes from N8N_ENCRYPTION_KEY env var)
const encryptionKey = "test-encryption-key-12345";

console.log("Encrypting credential data...");
const encrypted = encrypt(credentialData, encryptionKey);
console.log();
console.log("Encrypted (base64):");
console.log(encrypted.substring(0, 100) + "...");
console.log("Encrypted length:", encrypted.length, "characters");
console.log();

console.log("Decrypting...");
const decrypted = decrypt(encrypted, encryptionKey);
console.log();
console.log("Decrypted data:");
console.log(decrypted);
console.log();

// Parse back to object
let decryptedObj;
try {
	decryptedObj = JSON.parse(decrypted);
	console.log("Decrypted token:");
	console.log(decryptedObj.token);
	console.log();
	console.log("Decrypted token length:", decryptedObj.token.length, "characters");
	console.log();
} catch (error) {
	console.error("Failed to parse decrypted data:", error.message);
}

// Compare
console.log("=".repeat(80));
console.log("COMPARISON RESULTS:");
console.log("=".repeat(80));
console.log();

if (decryptedObj && decryptedObj.token === jwtToken) {
	console.log("✅ SUCCESS: Decrypted token matches original!");
	console.log("✅ No truncation occurred!");
} else if (decryptedObj && decryptedObj.token) {
	console.log("❌ FAIL: Decrypted token does NOT match original!");
	console.log();
	console.log("Expected length:", jwtToken.length);
	console.log("Actual length:", decryptedObj.token.length);
	console.log();
	if (decryptedObj.token.length < jwtToken.length) {
		console.log("❌ TRUNCATION DETECTED!");
		console.log("Missing characters:", jwtToken.length - decryptedObj.token.length);
	}
	console.log();
	console.log("First difference at position:", 
		[...jwtToken].findIndex((char, i) => char !== decryptedObj.token[i]));
} else {
	console.log("❌ FAIL: Decryption failed completely!");
}
console.log();
console.log("=".repeat(80));

