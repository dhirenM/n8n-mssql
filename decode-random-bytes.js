const crypto = require('crypto');

// The hex string from cipher.ts
const hexString = '53616c7465645f5f';

// Convert to Buffer and then to ASCII string
const buffer = Buffer.from(hexString, 'hex');
const asciiString = buffer.toString('ascii');

console.log("Hex string:", hexString);
console.log("As ASCII:", asciiString);
console.log("Buffer:", buffer);
console.log();

// Show byte by byte
console.log("Byte-by-byte breakdown:");
for (let i = 0; i < buffer.length; i++) {
    const hex = buffer[i].toString(16).padStart(2, '0');
    const char = String.fromCharCode(buffer[i]);
    console.log(`  ${hex} = '${char}'`);
}

