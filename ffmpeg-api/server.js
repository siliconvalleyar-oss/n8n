const express = require('express');
const { execFile, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const app = express();

app.use(express.json({ limit: '50mb' }));

const FFMPEG = 'ffmpeg';
const FFPROBE = 'ffprobe';

function run(args) {
  return new Promise((resolve, reject) => {
    execFile(FFMPEG, args, { timeout: 300000 }, (err, stdout, stderr) => {
      if (err) return reject(new Error(stderr || err.message));
      resolve(stdout);
    });
  });
}

function runProbe(file) {
  return new Promise((resolve, reject) => {
    execFile(FFPROBE, ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file], { timeout: 10000 }, (err, stdout) => {
      if (err) return reject(err);
      resolve(parseFloat(stdout.trim()));
    });
  });
}

function ensureDir(p) {
  const dir = path.dirname(p);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', ffmpeg: true }));

// Run any ffmpeg command
app.post('/exec', async (req, res) => {
  try {
    const { args, description } = req.body;
    if (!args || !Array.isArray(args)) return res.status(400).json({ error: 'args array required' });
    console.log(`[ffmpeg-api] ${description || 'exec'}: ffmpeg ${args.join(' ')}`);
    const stdout = await run(args);
    res.json({ success: true, stdout });
  } catch (e) {
    console.error(`[ffmpeg-api] error: ${e.message}`);
    res.status(500).json({ error: e.message });
  }
});

// Full TikTok pipeline
app.post('/tiktok-pipeline', async (req, res) => {
  try {
    const cfg = req.body;
    const { jobId, inputPath, outputPath, targetDuration, includeWatermark, includeCaptions, backgroundMusic, speed, script } = cfg;
    const tmp = (name) => `/tmp/${jobId}_${name}`;

    ensureDir(outputPath);

    // 1. Resize to 9:16
    console.log(`[${jobId}] 1/6 Resize`);
    await run(['-i', inputPath, '-vf', 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black', '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-b:v', '4000k', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '128k', '-af', 'loudnorm=I=-14:LRA=1:TP=-1', '-y', tmp('01_resized.mp4')]);

    // 2. Trim
    console.log(`[${jobId}] 2/6 Trim`);
    await run(['-i', tmp('01_resized.mp4'), '-t', String(targetDuration || 30), '-c:v', 'copy', '-c:a', 'copy', '-y', tmp('02_trimmed.mp4')]);

    // 3. Speed
    const s = parseFloat(speed) || 1.0;
    if (s !== 1.0) {
      console.log(`[${jobId}] 3/6 Speed x${s}`);
      await run(['-i', tmp('02_trimmed.mp4'), '-filter_complex', `[0:v]setpts=${1/s}*PTS[v];[0:a]atempo=${s}[a]`, '-map', '[v]', '-map', '[a]', '-c:v', 'libx264', '-b:v', '4000k', '-c:a', 'aac', '-y', tmp('03_sped.mp4')]);
    } else {
      fs.copyFileSync(tmp('02_trimmed.mp4'), tmp('03_sped.mp4'));
    }

    // 4. Background music
    const bgmPath = backgroundMusic ? `/storage/assets/music/${backgroundMusic}.mp3` : null;
    if (bgmPath && fs.existsSync(bgmPath)) {
      console.log(`[${jobId}] 4/6 BGM: ${bgmPath}`);
      await run(['-i', tmp('03_sped.mp4'), '-i', bgmPath, '-filter_complex', '[1:a]volume=0.15[bgm];[0:a]volume=1.0[main];[main][bgm]amix=inputs=2:duration=first[out]', '-map', '0:v', '-map', '[out]', '-c:v', 'copy', '-c:a', 'aac', '-shortest', '-y', tmp('04_music.mp4')]);
    } else {
      fs.copyFileSync(tmp('03_sped.mp4'), tmp('04_music.mp4'));
    }

    // 5. Captions
    if (includeCaptions && script) {
      console.log(`[${jobId}] 5/6 Captions`);
      const lines = script.match(/.{1,36}(\s|$)/g) || [script];
      const dur = targetDuration || 30;
      const chunk = dur / lines.length;
      let srt = '';
      lines.forEach((line, i) => {
        const start = i * chunk;
        const end = (i + 1) * chunk;
        const pad = (n) => String(n).padStart(2, '0');
        const fmt = (s) => `${pad(Math.floor(s/3600))}:${pad(Math.floor((s%3600)/60))}:${(s%60).toFixed(3).padStart(6,'0')}`;
        srt += `${i+1}\n${fmt(start)} --> ${fmt(end)}\n${line.trim()}\n\n`;
      });
      const srtPath = tmp('captions.srt');
      fs.writeFileSync(srtPath, srt);
      await run(['-i', tmp('04_music.mp4'), '-vf', `subtitles=${srtPath}:force_style='Fontsize=48,FontColor=white,BorderStyle=1,OutlineSize=2,Shadow=0,MarginV=80'`, '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-c:a', 'copy', '-movflags', '+faststart', '-y', tmp('05_captioned.mp4')]);
      fs.unlinkSync(srtPath);
    } else {
      fs.copyFileSync(tmp('04_music.mp4'), tmp('05_captioned.mp4'));
    }

    // 6. Watermark
    const wmPath = '/storage/assets/watermark.png';
    if (includeWatermark && fs.existsSync(wmPath)) {
      console.log(`[${jobId}] 6/6 Watermark`);
      await run(['-i', tmp('05_captioned.mp4'), '-i', wmPath, '-filter_complex', 'overlay=W-w-30:30:format=auto,format=yuv420p', '-c:v', 'libx264', '-b:v', '4000k', '-c:a', 'copy', '-movflags', '+faststart', '-y', outputPath]);
    } else {
      await run(['-i', tmp('05_captioned.mp4'), '-c:v', 'copy', '-c:a', 'copy', '-movflags', '+faststart', '-y', outputPath]);
    }

    // Cleanup
    ['01_resized', '02_trimmed', '03_sped', '04_music', '05_captioned'].forEach(f => {
      try { fs.unlinkSync(tmp(`${f}.mp4`)); } catch {}
    });

    const duration = await runProbe(outputPath).catch(() => 0);
    const stats = fs.statSync(outputPath);

    console.log(`[${jobId}] Done: ${outputPath}`);
    res.json({ success: true, jobId, outputPath, duration, sizeBytes: stats.size });
  } catch (e) {
    console.error(`[ffmpeg-api] pipeline error: ${e.message}`);
    res.status(500).json({ error: e.message });
  }
});

// Generate captions SRT and burn them into video
app.post('/captions', async (req, res) => {
  try {
    const { inputPath, outputPath, script } = req.body;
    if (!inputPath) return res.status(400).json({ error: 'inputPath required' });
    const dur = await runProbe(inputPath).catch(() => 30);
    const lines = (script || 'No text').match(/.{1,36}(\s|$)/g) || ['No text'];
    const chunk = dur / lines.length;
    let srt = '';
    lines.forEach((line, i) => {
      const start = i * chunk;
      const end = Math.min((i + 1) * chunk, dur);
      const pad = (n) => String(n).padStart(2, '0');
      const fmt = (s) => `${pad(Math.floor(s/3600))}:${pad(Math.floor((s%3600)/60))}:${(s%60).toFixed(3).padStart(6,'0')}`;
      srt += `${i+1}\n${fmt(start)} --> ${fmt(end)}\n${line.trim()}\n\n`;
    });
    const srtPath = `/tmp/cap_${Date.now()}.srt`;
    fs.writeFileSync(srtPath, srt);
    await run(['-i', inputPath, '-vf', `subtitles=${srtPath}:force_style='Fontsize=48,FontColor=white,BorderStyle=1,OutlineSize=2,Shadow=0,MarginV=80'`, '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-c:a', 'copy', '-movflags', '+faststart', '-y', outputPath || inputPath.replace('.mp4', '_captioned.mp4')]);
    fs.unlinkSync(srtPath);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Download a file via curl
app.post('/download', async (req, res) => {
  try {
    const { url, output } = req.body;
    if (!url || !output) return res.status(400).json({ error: 'url and output required' });
    ensureDir(output);
    execSync(`curl -L -o "${output}" "${url}"`, { timeout: 120000 });
    res.json({ success: true, output });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Run a shell command
app.post('/shell', async (req, res) => {
  try {
    const { command } = req.body;
    if (!command) return res.status(400).json({ error: 'command required' });
    const stdout = execSync(command, { timeout: 30000, encoding: 'utf8' });
    res.json({ success: true, stdout });
  } catch (e) {
    res.status(500).json({ error: e.message, stderr: e.stderr?.toString() });
  }
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => console.log(`ffmpeg-api listening on port ${PORT}`));
