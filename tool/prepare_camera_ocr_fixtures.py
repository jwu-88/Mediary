"""Reproducible adverse-condition OCR inputs derived from official package images.
These are simulated inputs, not physical camera captures. No text is added to any label.
"""
from pathlib import Path
import json, math, hashlib, subprocess, argparse
import numpy as np
from PIL import Image, ImageFilter, ImageOps, ImageDraw
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir',default='/private/tmp/mediary-cylinder-fixtures')
parser.add_argument('--benadryl-camera-screenshot',help='Optional private camera-preview screenshot; never upload or publish this input')
parser.add_argument('--excedrin-review-screenshot',help='Optional private review screenshot with an 83x82 thumbnail; never upload or publish this input')
args=parser.parse_args()
ROOT=Path(args.output_dir)
ROOT.mkdir(parents=True,exist_ok=True)
W,H=1024,768

def source(path,crop=None,transparent=False):
 im=Image.open(ROOT/path).convert('RGBA')
 if transparent:
  bounds=im.getchannel('A').getbbox()
  if bounds: im=im.crop(bounds)
 if crop: im=im.crop(crop)
 bg=Image.new('RGBA',im.size,(226,225,219,255)); bg.alpha_composite(im)
 return bg.convert('RGB')

def cylindrical(im,angle_deg=60,arch_ratio=.04):
 """Simulate a flat label seen on a cylinder; it does not reconstruct hidden text."""
 im=ImageOps.contain(im,(820,600),Image.Resampling.LANCZOS)
 arr=np.asarray(im).astype(np.float32); h,w=arr.shape[:2]
 theta=math.radians(angle_deg)
 yn,xn=np.indices((h,w),dtype=np.float32)
 dx=(xn/(w-1)*2-1)
 u=np.arcsin(np.clip(dx*math.sin(theta),-1,1))/theta
 sx=(u+1)*(w-1)/2
 scale=.96+.04*np.cos(u*theta)
 sy=(yn-h/2-arch_ratio*h*(dx*dx-.5))/scale+h/2
 x0=np.floor(sx).astype(int); y0=np.floor(sy).astype(int)
 x0=np.clip(x0,0,w-1); y0=np.clip(y0,0,h-1)
 x1=np.minimum(x0+1,w-1); y1=np.minimum(y0+1,h-1)
 fx=(sx-x0)[...,None]; fy=(sy-y0)[...,None]
 out=(arr[y0,x0]*(1-fx)*(1-fy)+arr[y0,x1]*fx*(1-fy)+arr[y1,x0]*(1-fx)*fy+arr[y1,x1]*fx*fy)
 shade=(.73+.27*np.cos(u*theta))[...,None]
 out=np.clip(out*shade,0,255).astype('uint8')
 return Image.fromarray(out)

def scene(im,angle=0,brightness=.65,blur=.65,label_width=740,label_height=580,glare=False):
 im=ImageOps.contain(im,(label_width,label_height),Image.Resampling.LANCZOS)
 im=im.convert('RGBA').rotate(angle,resample=Image.Resampling.BICUBIC,expand=True)
 yy,xx=np.indices((H,W),dtype=np.float32)
 gray=70+10*np.sin(xx/132)+7*np.cos(yy/85)
 arr=np.stack([gray*.94,gray*.98,gray],axis=-1).clip(0,255).astype('uint8')
 bg=Image.fromarray(arr).convert('RGBA')
 bg.alpha_composite(im,((W-im.width)//2,(H-im.height)//2))
 arr=np.asarray(bg.convert('RGB')).astype(float)
 # Side lighting, dim exposure, and soft vignette applied to whole frame.
 light=.82+.18*(xx/W)
 vignette=1-.22*((xx-W/2)**2/(W/2)**2+(yy-H/2)**2/(H/2)**2)
 arr*=brightness*light[...,None]*vignette[...,None]
 if glare:
  band=np.exp(-((xx-665)/45)**2)*np.exp(-((yy-300)/155)**2)
  arr=arr*(1-.48*band[...,None])+242*(.48*band[...,None])
 return Image.fromarray(arr.clip(0,255).astype('uint8')).filter(ImageFilter.GaussianBlur(blur))

entries=[
 dict(id='excedrin_cylindrical_dim_tilt',brand='Excedrin',variant='Migraine Relief',ingredients=['acetaminophen 250 mg','aspirin 250 mg','caffeine 65 mg'],source_file='excedrin-source.png',page_url='https://www.excedrin.com/products/head-pain-relief/migraine/',image_url='https://i-cf65.ch-static.com/content/dam/cf-consumer-healthcare/bp-excedrin-v2/en_US/products/migraine/excredrin-migraine-bottle.png',crop=None,transparent=True,cylinder=None,condition='Actual curved bottle packshot with simulated dim exposure, 11 degree tilt, and mild blur',angle=11,brightness=.69,blur=.60,label_width=720,label_height=610),
 dict(id='advil_curved_low_light',brand='Advil',variant='Tablets',ingredients=['ibuprofen 200 mg'],source_file='advil-source.png',page_url='https://www.advil.com/our-products/advil-pain/advil-tablets/',image_url='https://i-cf65.ch-static.com/content/dam/cf-consumer-healthcare/bp-advil-v2/en_US/products/product-01/avl204-packshots/products-advil-pain/adviltablets.jpg',crop=None,transparent=False,cylinder=67,condition='Flat manufacturer label projected around a cylinder, simulated dim side lighting and 8 degree tilt',angle=-8,brightness=.61,blur=.65,label_width=830,label_height=570),
 dict(id='tylenol_dim_blur_tilt',brand='Tylenol',variant='Extra Strength Caplets',ingredients=['acetaminophen 500 mg'],source_file='tylenol-source.png',page_url='https://www.tylenol.com/products/headache-pain-relief/tylenol-extra-strength-caplets',image_url='https://images.ctfassets.net/g574hlexgjps/Pw9NPMsex8BV3YV94CPOq/7732fdecf47f82b65e6ba145f94bca6d/4e0ef5c9c7babce9f089625072c3df6aa927a42a.webp?fm=png&q=100&w=1920',crop=None,transparent=True,cylinder=None,condition='Carton packshot with simulated dim exposure, 13 degree tilt, and defocus blur',angle=-13,brightness=.54,blur=1.15,label_width=760,label_height=610),
 dict(id='aleve_curved_dim_tilt',brand='Aleve',variant='Tablets',ingredients=['naproxen sodium 220 mg'],source_file='aleve-source.png',page_url='https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=00ef5b30-71d0-4cb4-84a3-48c67d1cea2a',image_url='https://dailymed.nlm.nih.gov/dailymed/image.cfm?name=Aleve+Tablets+-+24+Count+Carton.jpg&setid=00ef5b30-71d0-4cb4-84a3-48c67d1cea2a',crop=[1670,660,2450,1920],transparent=False,cylinder=64,condition='NIH DailyMed front panel projected around a cylinder with dim side lighting, 14 degree tilt, and mild blur',angle=14,brightness=.59,blur=.75,label_width=790,label_height=580),
 dict(id='claritin_curved_glare',brand='Claritin',variant='24 Hour Tablets',ingredients=['loratadine 10 mg'],source_file='claritin-pouch-source.png',page_url='https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=677bf76d-e75d-4212-b1f2-eaaf25b27cb7',image_url='https://dailymed.nlm.nih.gov/dailymed/image.cfm?name=claritin-01.jpg&setid=677bf76d-e75d-4212-b1f2-eaaf25b27cb7',crop=[342,27,660,470],transparent=False,cylinder=57,condition='NIH DailyMed front panel projected around a cylinder with mild glare, dim exposure, 7 degree tilt, and blur',angle=-7,brightness=.67,blur=.70,label_width=800,label_height=600,glare=True),
 dict(id='benadryl_dim_blur_tilt',brand='Benadryl',variant='Allergy Ultratabs Go Packs',ingredients=['diphenhydramine HCl 25 mg'],source_file='benadryl-source.png',page_url='https://www.benadryl.com/products/benadryl-allergy-ultratabs-tablets',image_url='https://images.ctfassets.net/00ko9qtwe33b/2Gju2xoNzxsIb2v9F8O4Wg/e1e93f6832dfba43acd2aaed7aa998ff/BEN_Front-of-Pack-for-300450170088_Allergy_ULTRATAB_Go_Packs_8ct.webp?fm=png&q=100&w=1920',crop=None,transparent=True,cylinder=None,condition='Carton packshot with simulated dim exposure, 10 degree tilt, and blur',angle=10,brightness=.60,blur=.90,label_width=740,label_height=610),
]
for entry in entries:
 source_path=ROOT/entry['source_file']
 if not source_path.exists():
  subprocess.run(['curl','--silent','--show-error','--fail','--location',entry['image_url'],'--output',str(source_path)],check=True)
 entry['source_sha256']=hashlib.sha256(source_path.read_bytes()).hexdigest()
 im=source(entry['source_file'],entry['crop'],entry['transparent'])
 im.save(ROOT/(entry['id']+'-baseline.png'))
 if entry['cylinder']: im=cylindrical(im,entry['cylinder'])
 result=scene(im,**{k:entry[k] for k in ('angle','brightness','blur','label_width','label_height')},glare=entry.get('glare',False))
 path=ROOT/(entry['id']+'.png'); result.save(path)
 entry['baseline_path']=str(ROOT/(entry['id']+'-baseline.png'))
 entry['test_path']=str(path)
 entry['input_kind']='synthetic degradation of official source'
 entry['physical_camera_capture']=False
 entry['expected_result']='Brand identified or manual-review fallback without false medication attribution; exact strength requires label confirmation'
expected={'Excedrin':'Excedrin Migraine','Advil':'Advil','Tylenol':'Tylenol','Aleve':'Aleve','Claritin':'Claritin','Benadryl':'Benadryl'}
accepted={'Excedrin':['Excedrin Migraine','Acetaminophen/Aspirin/Caffeine','Acetaminophen / Aspirin / Caffeine'],'Advil':['Advil','Ibuprofen'],'Tylenol':['Tylenol','Acetaminophen'],'Aleve':['Aleve','Naproxen','Naproxen Sodium'],'Claritin':['Claritin','Loratadine'],'Benadryl':['Benadryl','Diphenhydramine']}
for entry in entries:
 entry.update(path=entry['test_path'],expectedMedicationName=expected[entry['brand']],acceptedMedicationNames=accepted[entry['brand']],sourceUrl=entry['page_url'])
# Private captured examples are not included in the manufacturer contact sheet.
photo=Path(args.benadryl_camera_screenshot) if args.benadryl_camera_screenshot else None
if photo and photo.exists():
 Image.open(photo).crop((2,230,1050,1018)).save(ROOT/'private-user-benadryl-camera-crop.png')
 entries.append(dict(id='private_user_benadryl_camera_crop',brand='Benadryl',path=str(ROOT/'private-user-benadryl-camera-crop.png'),expectedMedicationName='Benadryl',acceptedMedicationNames=['Benadryl','Diphenhydramine'],condition='User-supplied camera preview crop; low light, tilt, and defocus are present in the original capture',sourceUrl='User attachment; local-only',input_kind='real user camera-preview screenshot crop',physical_camera_capture=True,crop=[2,230,1050,1018],privacy='Contains a person; do not upload or publish',ingredients=['diphenhydramine HCl 25 mg']))
review=Path(args.excedrin_review_screenshot) if args.excedrin_review_screenshot else None
if review and review.exists():
 Image.open(review).crop((151,78,234,160)).save(ROOT/'private-user-excedrin-tiny-thumbnail.png')
 entries.append(dict(id='private_user_excedrin_tiny_thumbnail',brand='Excedrin',path=str(ROOT/'private-user-excedrin-tiny-thumbnail.png'),expectedMedicationName=None,expectedManualReview=True,condition='83 by 82 pixel thumbnail cropped from user review screenshot; insufficient evidence for reliable exact identification',sourceUrl='User attachment; local-only',input_kind='real user review screenshot thumbnail crop',physical_camera_capture=False,crop=[151,78,234,160],privacy='Local test only; do not upload or publish'))
manifest={'purpose':'Test medication camera/OCR recognition on at least five distinct adverse-condition labels','fixture_generation':'Simulated low light, blur, rotation, glare, and cylinder projection; these inputs are not newly captured physical-camera photographs','sources':'Manufacturer images linked by official product pages, and NIH NLM DailyMed submitted package artwork','fixtures':entries}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
public_manifest={**manifest,'fixtures':entries[:6]}
(ROOT/'manifest-public.json').write_text(json.dumps(public_manifest,indent=2)+'\n')
contact=Image.new('RGB',(3*384,2*330),(238,238,238)); d=ImageDraw.Draw(contact)
for i,e in enumerate(entries[:6]):
 im=Image.open(e['test_path']); im=ImageOps.contain(im,(384,288)); x=i%3*384; y=i//3*330
 contact.paste(im,(x,y+30)); d.text((x+10,y+10),e['brand']+' | simulated adverse conditions',fill=(20,20,20))
contact.save(ROOT/'low-condition-contact-sheet.png')
print(json.dumps([{'id':e['id'],'path':e['path'],'condition':e['condition']} for e in entries],indent=2))
