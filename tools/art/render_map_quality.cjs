const sharp=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const fs=require('fs');
(async()=>{const svg=fs.readFileSync('docs/art_sources/map_quality_20261001/metro_map.svg');for(const scale of [1,4]){const path=`game/assets/${scale===4?'world_detail/':''}city_map/aurelia_map.png`;await sharp(svg,{density:72*scale}).resize(640*scale,360*scale).png().toFile(path);}console.log('metro vector render: native and 4x');})();
