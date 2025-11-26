// This demonstrates the issue with unredact

const CREDENTIAL_BLANKING_VALUE = '__n8n_BLANK_VALUE_e5362baf-c777-4d57-a609-6eaf1f9e87f6';

// Simulate OLD data in database (has "…")
const oldDecryptedData = {
    token: 'eyJ...amr":…20"...old'  // Truncated with …
};

// Simulate NEW data from client (full token)
const newDataFromClient = {
    token: 'eyJ...full-token-no-ellipsis...'  // Full token
};

// Simulate what happens if user only changed the name, not the token
const newDataWithBlankValue = {
    token: CREDENTIAL_BLANKING_VALUE  // UI sends blank value if field wasn't edited
};

function unredactRestoreValues(unmerged, replacement) {
    for (const [key, value] of Object.entries(unmerged)) {
        if (value === CREDENTIAL_BLANKING_VALUE) {
            // Restore old value from database
            unmerged[key] = replacement[key];
            console.log(`  → Restored ${key} from old data:`, replacement[key].substring(0, 50) + '...');
        }
    }
}

console.log("=".repeat(80));
console.log("SCENARIO 1: User edits token field with FULL token");
console.log("=".repeat(80));
const scenario1 = { ...newDataFromClient };
console.log("Before unredact:", scenario1.token.substring(0, 50));
unredactRestoreValues(scenario1, oldDecryptedData);
console.log("After unredact:", scenario1.token.substring(0, 50));
console.log("Result: ✅ NEW token is kept");
console.log();

console.log("=".repeat(80));
console.log("SCENARIO 2: User only changes name, token field shows redacted");
console.log("=".repeat(80));
const scenario2 = { ...newDataWithBlankValue };
console.log("Before unredact:", scenario2.token);
unredactRestoreValues(scenario2, oldDecryptedData);
console.log("After unredact:", scenario2.token.substring(0, 50));
console.log("Result: ❌ OLD truncated token is restored!");
console.log();

console.log("=".repeat(80));
console.log("THE PROBLEM:");
console.log("=".repeat(80));
console.log("If the OLD database value has '…', and you only change the credential");
console.log("name (not the token field), unredact will restore the BAD old value!");
console.log();
console.log("SOLUTION: You MUST edit and re-paste the FULL token in the UI,");
console.log("then save. This ensures the new full token replaces the old bad one.");
console.log("=".repeat(80));

