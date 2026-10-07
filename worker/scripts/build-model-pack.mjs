import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync, readFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const source = resolve(root, 'work/private_models');
const outputDir = resolve(root, 'work/model_pack');
const output = resolve(outputDir, 'model-pack-v1.zip');
mkdirSync(outputDir, {recursive: true});
rmSync(output, {force: true});
execFileSync('zip', ['-j', '-X', output,
  resolve(source, 'mobileFaceNetARCNET.tflite'),
  resolve(source, 'minifas_v2_2.7_80.tflite'),
  resolve(source, 'minifas_v1se_4.0_80.tflite'),
], {stdio: 'inherit'});
const digest = createHash('sha256').update(readFileSync(output)).digest('hex');
console.log(`Model pack: ${output}`);
console.log(`MODEL_PACK_SHA256=${digest}`);
