import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const html=await readFile(new URL('./intro_shell.html',import.meta.url),'utf8');
const code=html.split('// BEGIN SHARED INTRO')[1].split('// END SHARED INTRO')[0];
function fixture(){
 const nodes=new Map(), events={};
 for(const id of ['journey-intro','intro-message','intro-progress','intro-fill','intro-start','canvas']){
  nodes.set(id,{hidden:false,disabled:true,textContent:'',dataset:{},style:{},attrs:{},
   classList:{add(){},remove(){}},addEventListener(name,fn){events[id+name]=fn;},
   setAttribute(name,value){this.attrs[name]=value;},removeAttribute(name){delete this.attrs[name];},focus(){}});
 }
 const window={location:{reload(){}}};
 const document={getElementById:id=>nodes.get(id),addEventListener(name,fn){events[name]=fn;}};
 vm.runInNewContext(code,{window,document});
 return {api:window.untamedIntro,nodes,click:()=>events['journey-introclick']({preventDefault(){},stopPropagation(){}}),
  key:repeat=>events.keydown({key:'Enter',repeat,preventDefault(){},stopImmediatePropagation(){}})};
}
test('loading never accepts or queues activation; readiness requires fresh input',()=>{
 const f=fixture();let calls=0;
 f.api.show('intro',()=>calls++);f.click();f.key(false);
 assert.equal(calls,0);
 f.api.update('intro','ready','');f.key(true);assert.equal(calls,0);
 f.key(false);f.click();assert.equal(calls,1);
});
test('one overlay is reused and stale owners cannot dismiss another screen',()=>{
 const f=fixture();f.api.show('intro',()=>{});f.api.update('intro','ready','');f.api.hide('intro');
 f.api.show('transition',()=>{});f.api.hide('intro');
 assert.equal(f.nodes.get('journey-intro').hidden,false);
 assert.equal(f.nodes.get('journey-intro').dataset.phase,'loading');
 f.api.loading('포켓몬 50%',50,100);
 assert.equal(f.nodes.get('intro-fill').style.width,'50%');
 assert.equal(f.nodes.get('intro-progress').attrs['aria-valuenow'],'50');
});
test('download failure offers retry and never shows the start prompt',()=>{
 const f=fixture();f.api.error('연결을 확인해 주세요.');
 assert.equal(f.nodes.get('journey-intro').dataset.phase,'error');
 assert.equal(f.nodes.get('intro-start').textContent,'다시 시도');
 assert.equal(f.nodes.get('intro-start').disabled,false);
});
test('gameplay loading and errors cannot reopen the dismissed intro',()=>{
 const f=fixture();f.api.show('intro',()=>{});f.api.update('intro','ready','');f.api.hide('intro');
 f.api.loading('포켓몬 준비 중…',50,100);f.api.error('자료를 받지 못했습니다.');
 assert.equal(f.nodes.get('journey-intro').hidden,true,'Runtime ball cover keeps sole ownership of loading feedback');
});
