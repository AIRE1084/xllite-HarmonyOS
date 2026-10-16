'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
(async()=>{
 const response=await fetch('https://xllite.sayqz.com/api/v1/features/detail',{signal:AbortSignal.timeout(15000)});
 assert.equal(response.status,200);const body=await response.json();assert.ok(Array.isArray(body.features));
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/services/XlliteGateway.ets'),'utf8');
 const features=body.features.map(f=>({name:f.name,params:f.paramsSchema,request:f.requestExample,response:f.responseExample}));
 for(const f of features){assert.ok(source.includes("'"+f.name+"'"),'Missing client feature: '+f.name); console.log('PASS '+f.name+' public contract');}
 const dest=path.join(root,'.wolf/api23-native-login');fs.mkdirSync(dest,{recursive:true});fs.writeFileSync(path.join(dest,'feature-contracts.json'),JSON.stringify({checkedAt:new Date().toISOString(),source:'https://xllite.sayqz.com/api/v1/features/detail',features},null,2));
 console.log(features.length+' feature contracts inspected; authenticated behavior remains separate.');
})().catch(e=>{console.error(e.message);process.exitCode=1});
