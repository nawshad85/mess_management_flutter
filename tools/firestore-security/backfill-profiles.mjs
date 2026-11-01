// Additive migration: only memberProfiles and inviteCodes are written.
// Private users, messes, financial records, and invitations are never changed.
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { Firestore } from 'firebase-admin/firestore';

const projectId = process.argv[process.argv.indexOf('--project') + 1];
if (!process.argv.includes('--project') || projectId !== 'fluid-cosmos-467914-b1') {
  throw new Error('Explicit --project fluid-cosmos-467914-b1 is required');
}
if (process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Unset FIRESTORE_EMULATOR_HOST for the production backfill');
const apply = process.argv.includes('--apply');
const require = createRequire(import.meta.url);
const globalModules = execFileSync(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['root', '-g'], {
  encoding:'utf8', shell:process.platform === 'win32',
}).trim();
const auth = require(join(globalModules,'firebase-tools/lib/auth.js'));
const cliApi = require(join(globalModules,'firebase-tools/lib/api.js'));
const account = auth.getProjectDefaultAccount(process.cwd());
if (!account) throw new Error('Run firebase login first');
const db=new Firestore({projectId,credentials:{
  type:'authorized_user',client_id:cliApi.clientId(),client_secret:cliApi.clientSecret(),
  refresh_token:account.tokens.refresh_token,
}});
const snapshot=await db.collection('users').get();
const codes=new Set();
function sanitize(doc) {
  const data=doc.data();
  if (data.uid !== doc.id || !/^[A-Z0-9]{8}$/.test(data.uniqueId)) {
    throw new Error('An existing profile has an invalid UID or invite code; migration stopped');
  }
  const shared={uid:doc.id,name:data.name??data.username??'',uniqueId:data.uniqueId,
    messId:data.messId??null,role:data.role??'member',roomId:data.roomId??null};
  return {shared,lookup:{uid:doc.id,name:shared.name,messId:shared.messId}};
}
// Validate the full source and existing code ownership before writing anything.
for (const doc of snapshot.docs) {
  const {shared}=sanitize(doc);
  if(codes.has(shared.uniqueId)) throw new Error('Duplicate invite codes found; migration stopped');
  codes.add(shared.uniqueId);
  const existing=await db.collection('inviteCodes').doc(shared.uniqueId).get();
  if(existing.exists && existing.data().uid!==doc.id) throw new Error('Invite-code ownership conflict; migration stopped');
}
console.log(JSON.stringify({projectId,mode:apply?'apply':'dry-run',userCount:snapshot.size}));
if(apply) {
  for (const doc of snapshot.docs) {
    await db.runTransaction(async transaction=>{
      const latest=await transaction.get(doc.ref);
      const {shared,lookup}=sanitize(latest);
      const lookupRef=db.collection('inviteCodes').doc(shared.uniqueId);
      const existing=await transaction.get(lookupRef);
      if(existing.exists && existing.data().uid!==doc.id) throw new Error('Invite-code ownership conflict');
      transaction.set(db.collection('memberProfiles').doc(doc.id),shared);
      transaction.set(lookupRef,lookup);
    });
  }
  console.log(JSON.stringify({sanitizedProfilesWritten:snapshot.size,lookupRecordsWritten:snapshot.size,privateRecordsChanged:0}));
}
await db.terminate();
