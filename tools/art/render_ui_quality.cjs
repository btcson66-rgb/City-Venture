const fs=require('fs'),path=require('path');
const sharp=require(process.env.CITY_SHARP||'C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),src=path.join(root,'docs/art_sources/ui_quality_20261001');
async function main(){
 const jobs=JSON.parse(fs.readFileSync(path.join(src,'render_jobs.json')));
 for(const factor of [1,4]){
  const base=path.join(root,'game/assets',factor===4?'world_detail':'');
  for(const job of jobs){
   const output=path.join(base,job.key+'.png');fs.mkdirSync(path.dirname(output),{recursive:true});
   await sharp(path.join(root,job.source)).resize(job.size[0]*factor,job.size[1]*factor).png().toFile(output);
  }
  const icons=jobs.filter(j=>j.key.startsWith('ui/icons/'));
  const layers=icons.map((j,i)=>({input:path.join(base,j.key+'.png'),left:(i%8)*16*factor,top:Math.floor(i/8)*16*factor}));
  await sharp({create:{width:128*factor,height:96*factor,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(layers).png().toFile(path.join(base,'ui/icons_atlas.png'));
 }
 console.log('Rendered 43 semantic icons, 23 surfaces/frames and fixed-slot atlas at native and 4x.');
}
main().catch(e=>{console.error(e);process.exit(1)});
