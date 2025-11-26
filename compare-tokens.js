const crypto = require('crypto');

// The TRUNCATED token (what's currently stored)
const truncatedToken = `eyJhbGciOiJSUzI1NiIsImtpZCI6IjdFRTlBREIzRTYyRjc3Q0NERDg1N0ZEOEZGRjAzQUNBQUUwNUNCMjlSUzI1NiIsIng1dCI6ImZ1bXRzLVl2ZDh6ZGhYX1lfX0E2eXE0Rnl5ayIsInR5cCI6ImF0K2p3dCJ9.eyJpc3MiOiJodHRwczovL3lhcmRpc2FsZXMueWFyZGlvbmVjb3JlcWEuY29tL3lBdXRoMi9pZGVudGl0eSIsIm5iZiI6MTc2MzYyNzgyMiwiaWF0IjoxNzYzNjI3ODIyLCJleHAiOjE3NjM2MzE0MjIsImF1ZCI6Imh0dHBzOi8veWFyZGlzYWxlcy55YXJkaW9uZWNvcmVxYS5jb20veUF1dGgyL2lkZW50aXR5L3Jlc291cmNlcyIsInNjb3BlIjpbIm9wZW5pZCIsInByb2ZpbGUiLCJlbWFpbCIsIm9mZmxpbmVfYWNjZXNzIl0sImFtciI6WyJleHRlcm5hbCJdLCJjbGllbnRfaWQiOiJ5YXJkaXNhbGVzX21jcCIsInN1YiI6IjU2NmNjYWY4LWNhZWMtNGFjZi1hMzRmLWQ2MDUyYTg1NWM4MiIsImF1dGhfdGltZSI6MTc2MzYyNzgxNiwiaWRwIjoieWFyZGlzYWxlc195YXJkaWF6dXJlIiwid2luYWNjb3VudG5hbWUiOiJEaGlyZW4uTWlzdHJ5QFlhcmRpLkNvbSIsInlOYW1lIjoiRGhpcmVuLk1pc3RyeUBZYXJkaS5Db20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJEaGlyZW4uTWlzdHJ5QFlhcmRpLkNvbSIsImVtYWlsIjoiRGhpcmVuLk1pc3RyeUBZYXJkaS5Db20iLCJlbWFpbF92ZXJpZmllZCI6ImZhbHNlIiwiZ2l2ZW5fbmFtZSI6IkRoaXJlbiIsImZhbWlseV9uYW1lIjoiTWlzdHJ5Iiwic2lkIjoiNkEzMzFCNUM2QTI0ODkxRDY2RTJCQTQxQ0VFNzMyRTcifQ.ddcdzvAbvBpwfynnM1xgYoLoW9HehgWd1En5tecFjoGKJu6X0Q9C1ufRPwV2NTMYYh3CN3SZ663-yIIofIh-kdWIeA-RmBe5GrCOibn9M_KZnr-AApWs2ooqWANxkJtX2ZXdKGelhSge4ri5h96iS7qqHymAkDEDgkMQ3xvAjlR_iPm51oT1-HQJFFbpmBsFDTpP_e1zca07lVdCvtFySzpsIuhwEELrA6uxi1WWH_MQdgYRTmkZ1tDl-MUova9IhCjDM48lZEo9wTaUUefqA_XuZlcCORZZzmRU_Q1DoLeMMgwBdYKj6EYarXhkfFIL3C64Vn7jhdsQtXCwqDdecg`;

// The FULL token (what you SHOULD paste)
const fullToken = `eyJhbGciOiJSUzI1NiIsImtpZCI6IjdFRTlBREIzRTYyRjc3Q0NERDg1N0ZEOEZGRjAzQUNBQUUwNUNCMjlSUzI1NiIsIng1dCI6ImZ1bXRzLVl2ZDh6ZGhYX1lfX0E2eXE0Rnl5ayIsInR5cCI6ImF0K2p3dCJ9.eyJpc3MiOiJodHRwczovL3lhcmRpc2FsZXMueWFyZGlvbmVjb3JlcWEuY29tL3lBdXRoMi9pZGVudGl0eSIsIm5iZiI6MTc2MzYyNzgyMiwiaWF0IjoxNzYzNjI3ODIyLCJleHAiOjE3NjM2MzE0MjIsImF1ZCI6Imh0dHBzOi8veWFyZGlzYWxlcy55YXJkaW9uZWNvcmVxYS5jb20veUF1dGgyL2lkZW50aXR5L3Jlc291cmNlcyIsInNjb3BlIjpbIm9wZW5pZCIsInByb2ZpbGUiLCJlbWFpbCIsIm9mZmxpbmVfYWNjZXNzIl0sImFtciI6WyJleHRlcm5hbCJdLCJjbGllbnRfaWQiOiJ5YXJkaXNhbGVzX21jcCIsInN1YiI6IjU2NmNjYWY4LWNhZWMtNGFjZi1hMzRmLWQ2MDUyYTg1NWM4MiIsImF1dGhfdGltZSI6MTc2MzYyNzgxNiwiaWRwIjoieWFyZGlzYWxlc195YXJkaWF6dXJlIiwid2luYWNjb3VudG5hbWUiOiJEaGlyZW4uTWlzdHJ5QFlhcmRpLkNvbSIsInlOYW1lIjoiRGhpcmVuLk1pc3RyeUBZYXJkaS5Db20iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJEaGlyZW4uTWlzdHJ5QFlhcmRpLkNvbSIsImVtYWlsIjoiRGhpcmVuLk1pc3RyeUBZYXJkaS5Db20iLCJlbWFpbF92ZXJpZmllZCI6ImZhbHNlIiwiZ2l2ZW5fbmFtZSI6IkRoaXJlbiIsImZhbWlseV9uYW1lIjoiTWlzdHJ5Iiwic2lkIjoiNkEzMzFCNUM2QTI0ODkxRDY2RTJCQTQxQ0VFNzMyRTcifQ.ddcdzvAbvBpwfynnM1xgYoLoW9HehgWd1En5tecFjoGKJu6X0Q9C1ufRPwV2NTMYYh3CN3SZ663-yIIofIh-kdWIeA-RmBe5GrCOibn9M_KZnr-AApWs2ooqWANxkJtX2ZXdKGelhSge4ri5h96iS7qqHymAkDEDgkMQ3xvAjlR_iPm51oT1-HQJFFbpmBsFDTpP_e1zca07lVdCvtFySzpsIuhwEELrA6uxi1WWH_MQdgYRTmkZ1tDl-MUova9IhCjDM48lZEo9wTaUUefqA_XuZlcCORZZzmRU_Q1DoLeMMgwBdYKj6EYarXhkfFIL3C64Vn7jhdsQtXCwqDdecg`;

console.log("=".repeat(80));
console.log("TOKEN COMPARISON");
console.log("=".repeat(80));
console.log();
console.log("Truncated token length:", truncatedToken.length);
console.log("Full token length:", fullToken.length);
console.log();

// Find where they differ
let firstDiff = -1;
for (let i = 0; i < Math.min(truncatedToken.length, fullToken.length); i++) {
    if (truncatedToken[i] !== fullToken[i]) {
        firstDiff = i;
        break;
    }
}

if (firstDiff >= 0) {
    console.log("❌ TOKENS ARE DIFFERENT!");
    console.log("First difference at position:", firstDiff);
    console.log();
    console.log("Around position", firstDiff, ":");
    console.log("Truncated:", truncatedToken.substring(firstDiff - 10, firstDiff + 30));
    console.log("Full:     ", fullToken.substring(firstDiff - 10, firstDiff + 30));
} else if (truncatedToken.length !== fullToken.length) {
    console.log("❌ LENGTHS ARE DIFFERENT!");
    console.log("Truncated is", fullToken.length - truncatedToken.length, "characters shorter");
} else {
    console.log("✅ Tokens are identical!");
}

console.log();
console.log("=".repeat(80));
console.log("WHAT YOU NEED TO DO:");
console.log("=".repeat(80));
console.log();
console.log("1. Copy THIS FULL TOKEN (below) - select ALL of it:");
console.log();
console.log(fullToken);
console.log();
console.log("2. Open n8n UI > Credentials > Bearer Auth account");
console.log("3. REPLACE the token field with the FULL token above");
console.log("4. Save the credential");
console.log();
console.log("=".repeat(80));

