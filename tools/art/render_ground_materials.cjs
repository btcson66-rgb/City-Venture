const fs=require('fs'),path=require('path');
const sharp=require(process.env.CITY_SHARP||'C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'), src=path.join(root,'docs/art_sources/ground_materials_20261001');
async function main(){
 const jobs=JSON.parse(fs.readFileSync(path.join(src,'render_jobs.json')));
 for(const factor of [1,4]){
  const baseline=path.join(src,factor===1?'baseline_atlas.png':'baseline_detail_atlas.png');
  const layers=[];
  for(const job of jobs){
   const p=path.join(root,job.source);
   const svg=fs.readFileSync(p,'utf8').replace(/href="([^"#]+\.png)"/g,(_,relative)=>'href="data:image/png;base64,'+fs.readFileSync(path.resolve(path.dirname(p),relative)).toString('base64')+'"');
   const input=await sharp(Buffer.from(svg)).resize(16*factor,16*factor).png().toBuffer();
   layers.push({input,left:job.coord[0]*16*factor,top:job.coord[1]*16*factor});
  }
  const output=path.join(root,'game/assets',factor===4?'world_detail':'','tiles/atlas.png');
  fs.mkdirSync(path.dirname(output),{recursive:true});
  await sharp(baseline).composite(layers).png().toFile(output);
 }
 console.log('Rendered 28 outdoor cells at native and 4x; all other atlas pixels preserved.');
}
main().catch(e=>{console.error(e);process.exit(1)});
