import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, query, where, setDoc, updateDoc,
  deleteDoc, writeBatch, arrayUnion, arrayRemove, serverTimestamp, Timestamp,
  setLogLevel } from 'firebase/firestore';

setLogLevel('silent');
let env;
const code = uid => uid.toUpperCase().padEnd(8, '0');
const user = (uid, messId = null, role = 'member') => ({
  uid, name: uid, uniqueId: code(uid), email: `${uid}@example.test`,
  messId, role, roomId: null, managerPinHash: 'a'.repeat(64),
  managerPinSalt: uid, createdAt: Timestamp.now(),
});
const profile = u => Object.fromEntries(['uid', 'name', 'uniqueId', 'messId', 'role', 'roomId'].map(k => [k, u[k]]));
const lookup = u => ({uid:u.uid, name:u.name, messId:u.messId});
const db = uid => uid ? env.authenticatedContext(uid, {email:`${uid}@example.test`,email_verified:true}).firestore() : env.unauthenticatedContext().firestore();
const invitation = (id = 'invite', to = 'eve', messId = 'alpha', from = 'alice') => ({
  inviteId:id, messId, messName:messId, fromUserId:from, fromName:from,
  toUserId:to, status:'pending', createdAt:Timestamp.now(),
});
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-mess-security',firestore:{
    host:'127.0.0.1',port:8085,
    rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const d=context.firestore();
    const batch=writeBatch(d);
    for (const u of [user('alice','alpha','manager'),user('bob','alpha'),user('eve'),user('mallory'),user('carol','beta','manager'),user('dan','beta')]) {
      batch.set(doc(d,'users',u.uid),u);
      batch.set(doc(d,'memberProfiles',u.uid),profile(u));
      batch.set(doc(d,'inviteCodes',u.uniqueId),lookup(u));
    }
    for (const [id,managerId,memberIds] of [['alpha','alice',['alice','bob']],['beta','carol',['carol','dan']]]) {
      batch.set(doc(d,'messes',id),{messId:id,name:id,managerId,memberIds,roomCount:1,createdAt:Timestamp.now()});
      batch.set(doc(d,`messes/${id}/rooms/room`),{roomId:'room',memberIds:[],roomNumber:1,capacity:10});
    }
    batch.set(doc(d,'invitations/invite'),invitation());
    batch.set(doc(d,'messes/alpha/messages/msg'),{messageId:'msg',senderId:'alice',senderName:'alice',content:'hello',mentions:[],readBy:{},isEdited:false,createdAt:Timestamp.now()});
    batch.set(doc(d,'messes/alpha/bazarEntries/bazar'),{entryId:'bazar',addedBy:'bob',totalCost:1});
    batch.set(doc(d,'messes/alpha/mealEntries/meal'),{entryId:'meal',addedBy:'bob',meals:{bob:1}});
    await batch.commit();
  });
});

function accept(d, {uid='eve', inviteId='invite', messId='alpha', extraMess={}} = {}) {
  const batch=writeBatch(d);
  batch.update(doc(d,'invitations',inviteId),{status:'accepted'});
  batch.update(doc(d,'messes',messId),{memberIds:arrayUnion(uid),...extraMess});
  batch.update(doc(d,'users',uid),{messId,role:'member',roomId:null,membershipInvitationId:inviteId});
  batch.update(doc(d,'memberProfiles',uid),{messId,role:'member',roomId:null});
  batch.update(doc(d,'inviteCodes',code(uid)),{messId});
  return batch.commit();
}
function resetProfile(batch,d,uid) {
  const fields={messId:null,roomId:null,role:'member'};
  batch.update(doc(d,'users',uid),fields);
  batch.update(doc(d,'memberProfiles',uid),fields);
  batch.update(doc(d,'inviteCodes',code(uid)),{messId:null});
}

for (const path of ['users/alice','messes/alpha','memberProfiles/alice','inviteCodes/ALICE000','invitations/invite','messes/alpha/messages/msg']) {
  test(`anonymous access denied: ${path}`,()=>assertFails(getDoc(doc(db(),path))));
}
test('private profile is readable by its owner',()=>assertSucceeds(getDoc(doc(db('alice'),'users/alice'))));
for (const uid of ['bob','carol','mallory']) {
  test(`private email and PIN inaccessible to ${uid}`,()=>assertFails(getDoc(doc(db(uid),'users/alice'))));
}
test('private profile collections cannot be enumerated',()=>assertFails(getDocs(collection(db('alice'),'users'))));
test('co-members can read sanitized profiles',async()=>{
  const data=(await assertSucceeds(getDoc(doc(db('bob'),'memberProfiles/alice')))).data();
  assert.equal(data.email,undefined);assert.equal(data.managerPinHash,undefined);
});
test('outsiders cannot read member profiles',()=>assertFails(getDoc(doc(db('mallory'),'memberProfiles/alice'))));
test('shared profile collections cannot be enumerated',()=>assertFails(getDocs(collection(db('alice'),'memberProfiles'))));
test('explicit invite-code lookup reveals only minimal fields',async()=>{
  const data=(await assertSucceeds(getDoc(doc(db('alice'),'inviteCodes/EVE00000')))).data();
  assert.deepEqual(Object.keys(data).sort(),['messId','name','uid']);
});
test('invite codes cannot be enumerated',()=>assertFails(getDocs(collection(db('mallory'),'inviteCodes'))));
test('registration atomically creates private, member, and lookup profiles',async()=>{
  const d=db('newuser'),u=user('newuser'),batch=writeBatch(d);
  batch.set(doc(d,'users/newuser'),u);batch.set(doc(d,'memberProfiles/newuser'),profile(u));
  batch.set(doc(d,'inviteCodes',u.uniqueId),lookup(u));
  await assertSucceeds(batch.commit());
});
test('registration cannot inject a manager role',async()=>{
  const d=db('newuser'),u=user('newuser',null,'manager'),batch=writeBatch(d);
  batch.set(doc(d,'users/newuser'),u);batch.set(doc(d,'memberProfiles/newuser'),profile(u));
  batch.set(doc(d,'inviteCodes',u.uniqueId),lookup(u));await assertFails(batch.commit());
});
test('new registration cannot steal an existing invite code',async()=>{
  const d=db('newuser'),u={...user('newuser'),uniqueId:code('alice')},batch=writeBatch(d);
  batch.set(doc(d,'users/newuser'),u);batch.set(doc(d,'memberProfiles/newuser'),profile(u));
  batch.set(doc(d,'inviteCodes',u.uniqueId),lookup(u));await assertFails(batch.commit());
});
test('private fields cannot be copied into shared profiles',()=>assertFails(updateDoc(doc(db('alice'),'memberProfiles/alice'),{managerPinHash:'b'.repeat(64)})));
test('shared membership cannot be forged',()=>assertFails(updateDoc(doc(db('mallory'),'memberProfiles/mallory'),{messId:'alpha'})));
test('an owner can set their own PIN',()=>assertSucceeds(updateDoc(doc(db('alice'),'users/alice'),{managerPinHash:'b'.repeat(64),managerPinSalt:'alice'})));
test('a manager cannot overwrite another user PIN',()=>assertFails(updateDoc(doc(db('alice'),'users/bob'),{managerPinHash:'b'.repeat(64)})));
for (const fields of [{role:'manager'},{messId:'beta',role:'manager'},{email:'other@example.test'},{uniqueId:'HACK0000'}]) {
  test(`private identity or privilege tampering denied: ${JSON.stringify(fields)}`,()=>assertFails(updateDoc(doc(db('bob'),'users/bob'),fields)));
}
test('outsiders cannot read a mess',()=>assertFails(getDoc(doc(db('mallory'),'messes/alpha'))));
test('mess members can read their mess',()=>assertSucceeds(getDoc(doc(db('bob'),'messes/alpha'))));
test('a missing mess can be observed without exposing any existing mess',async()=>{
  const snapshot=await assertSucceeds(getDoc(doc(db('eve'),'messes/deleted')));
  assert.equal(snapshot.exists(),false);
});
test('outsider cannot add themselves to a mess',()=>assertFails(updateDoc(doc(db('mallory'),'messes/alpha'),{memberIds:arrayUnion('mallory')})));
test('manager cannot bypass invitations to add an account',()=>assertFails(updateDoc(doc(db('alice'),'messes/alpha'),{memberIds:arrayUnion('mallory')})));
test('member cannot replace the manager',()=>assertFails(updateDoc(doc(db('bob'),'messes/alpha'),{managerId:'bob'})));
test('even manager cannot transfer ownership through a raw update',()=>assertFails(updateDoc(doc(db('alice'),'messes/alpha'),{managerId:'bob'})));
test('invitation acceptance cannot be split into independent writes',()=>assertFails(updateDoc(doc(db('eve'),'invitations/invite'),{status:'accepted'})));
test('valid invitation is accepted atomically',async()=>{
  const d=db('eve');await assertSucceeds(accept(d));
  await assertSucceeds(getDoc(doc(d,'messes/alpha/messages/msg')));
});
test('acceptance cannot also modify mess metadata',()=>assertFails(accept(db('eve'),{extraMess:{name:'hijacked'}})));
test('another recipient cannot accept an invitation',()=>assertFails(accept(db('mallory'),{uid:'mallory'})));
test('invitation cannot grant access to another mess',()=>assertFails(accept(db('eve'),{messId:'beta'})));
for (const status of ['declined','accepted']) {
  test(`${status} invitation cannot be replayed`,async()=>{
    await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'invitations/invite'),{status}));
    await assertFails(accept(db('eve')));
  });
}
test('an account already in a mess cannot accept another membership',async()=>{
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'invitations/invite'),invitation('invite','dan')));
  await assertFails(accept(db('dan'),{uid:'dan'}));
});
test('recipient can query their pending invitations',()=>assertSucceeds(getDocs(query(collection(db('eve'),'invitations'),where('toUserId','==','eve'),where('status','==','pending')))));
test('manager can query invitations for mess deletion',()=>assertSucceeds(getDocs(query(collection(db('alice'),'invitations'),where('messId','==','alpha')))));
test('outsiders cannot enumerate invitations',()=>assertFails(getDocs(collection(db('mallory'),'invitations'))));
test('a non-manager cannot create invitations',()=>assertFails(setDoc(doc(db('bob'),'invitations/fake'),invitation('fake','mallory','alpha','bob'))));
test('a manager can invite an available user',()=>assertSucceeds(setDoc(doc(db('alice'),'invitations/second'),invitation('second','mallory'))));
test('recipient cannot change invitation identity',()=>assertFails(updateDoc(doc(db('eve'),'invitations/invite'),{messId:'beta',status:'declined'})));
test('recipient can decline without joining',()=>assertSucceeds(updateDoc(doc(db('eve'),'invitations/invite'),{status:'declined'})));
test('another user cannot decline someone else invitation',()=>assertFails(updateDoc(doc(db('mallory'),'invitations/invite'),{status:'declined'})));
test('manager can remove a member with sanitized profile updates',async()=>{
  const d=db('alice'),batch=writeBatch(d);
  batch.update(doc(d,'messes/alpha'),{memberIds:arrayRemove('bob')});resetProfile(batch,d,'bob');
  await assertSucceeds(batch.commit());
  await assertFails(getDoc(doc(db('bob'),'messes/alpha/messages/msg')));
});
test('manager can assign a member to a room',async()=>{
  const d=db('alice'),batch=writeBatch(d);
  batch.update(doc(d,'messes/alpha/rooms/room'),{memberIds:arrayUnion('bob')});
  batch.update(doc(d,'users/bob'),{roomId:'room'});batch.update(doc(d,'memberProfiles/bob'),{roomId:'room'});
  await assertSucceeds(batch.commit());
});
test('room assignments cannot point to a room that does not include the member',()=>assertFails(updateDoc(doc(db('alice'),'users/bob'),{roomId:'missing'})));
test('member cannot grant themselves a room assignment',()=>assertFails(updateDoc(doc(db('bob'),'users/bob'),{roomId:'room'})));
test('manager creation and profile activation preserve the app sequence',async()=>{
  const d=db('eve');
  await assertSucceeds(setDoc(doc(d,'messes/new'),{messId:'new',name:'new',managerId:'eve',memberIds:['eve'],roomCount:1,createdAt:Timestamp.now()}));
  const batch=writeBatch(d),fields={messId:'new',role:'manager',roomId:null};
  batch.update(doc(d,'users/eve'),fields);batch.update(doc(d,'memberProfiles/eve'),fields);
  batch.update(doc(d,'inviteCodes/EVE00000'),{messId:'new'});await assertSucceeds(batch.commit());
});
test('mess creation cannot force-add other users',()=>assertFails(setDoc(doc(db('eve'),'messes/new'),{messId:'new',name:'new',managerId:'eve',memberIds:['eve','mallory'],roomCount:1,createdAt:Timestamp.now()})));
for (const child of ['rooms','bazarEntries','mealEntries','messages','notices','monthlySummaries','monthlyDeposits']) {
  test(`other-mess writes denied: ${child}`,()=>assertFails(setDoc(doc(db('dan'),`messes/alpha/${child}/attack`),{addedBy:'dan',entryId:'attack',senderId:'dan',messageId:'attack'})));
}
test('member cannot write a manager notice',()=>assertFails(setDoc(doc(db('bob'),'messes/alpha/notices/new'),{title:'fake'})));
test('member cannot forge a financial-entry author',()=>assertFails(setDoc(doc(db('bob'),'messes/alpha/bazarEntries/new'),{entryId:'new',addedBy:'alice'})));
test('members retain legitimate financial-entry writes',()=>assertSucceeds(setDoc(doc(db('bob'),'messes/alpha/mealEntries/new'),{entryId:'new',addedBy:'bob',meals:{bob:1}})));
test('message sender identity cannot be forged',()=>assertFails(setDoc(doc(db('bob'),'messes/alpha/messages/new'),{messageId:'new',senderId:'alice'})));
test('members can send a correctly attributed message',()=>assertSucceeds(setDoc(doc(db('bob'),'messes/alpha/messages/new'),{
  messageId:'new',senderId:'bob',senderName:'bob',content:'hello',mentions:[],readBy:{},isEdited:false,createdAt:Timestamp.now(),
})));
test('members cannot impersonate another display name',()=>assertFails(setDoc(doc(db('bob'),'messes/alpha/messages/new'),{
  messageId:'new',senderId:'bob',senderName:'alice',content:'fake',mentions:[],readBy:{},isEdited:false,createdAt:Timestamp.now(),
})));
test('only sender can edit message content',async()=>{
  await assertFails(updateDoc(doc(db('bob'),'messes/alpha/messages/msg'),{content:'fake',isEdited:true}));
  await assertSucceeds(updateDoc(doc(db('alice'),'messes/alpha/messages/msg'),{content:'edited',isEdited:true}));
});
test('members can acknowledge only their own read receipt',async()=>{
  await assertSucceeds(updateDoc(doc(db('bob'),'messes/alpha/messages/msg'),{'readBy.bob':serverTimestamp()}));
  await assertFails(updateDoc(doc(db('bob'),'messes/alpha/messages/msg'),{'readBy.alice':serverTimestamp()}));
});
test('manager reset and deletion cleanup remain authorized',async()=>{
  const d=db('alice'),batch=writeBatch(d);resetProfile(batch,d,'alice');resetProfile(batch,d,'bob');
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDocs(query(collection(d,'invitations'),where('messId','==','alpha'))));
  await assertSucceeds(deleteDoc(doc(d,'invitations/invite')));
  await assertSucceeds(deleteDoc(doc(d,'messes/alpha/messages/msg')));
  await assertSucceeds(deleteDoc(doc(d,'messes/alpha/rooms/room')));
  await assertSucceeds(deleteDoc(doc(d,'messes/alpha')));
});
test('four-user cleanup batches stay within rule access limits across chunks',async()=>{
  const ids=['alice','bob','eve','mallory','fifth'];
  await env.withSecurityRulesDisabled(async c=>{
    const d=c.firestore(),batch=writeBatch(d);
    batch.update(doc(d,'messes/alpha'),{memberIds:ids});
    for(const uid of ids) {
      const u=user(uid,'alpha',uid==='alice'?'manager':'member');
      batch.set(doc(d,'users',uid),u);batch.set(doc(d,'memberProfiles',uid),profile(u));
      batch.set(doc(d,'inviteCodes',code(uid)),lookup(u));
    }
    await batch.commit();
  });
  const d=db('alice'),first=writeBatch(d);
  for(const uid of ids.slice(0,4)) resetProfile(first,d,uid);
  await assertSucceeds(first.commit());
  await assertSucceeds(getDoc(doc(d,'memberProfiles/fifth')));
  const second=writeBatch(d);resetProfile(second,d,'fifth');await assertSucceeds(second.commit());
});
