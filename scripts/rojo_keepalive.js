const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const projectRoot = path.resolve(__dirname, "..");
const rojoExe = "C:\\Users\\Andrew\\.aftman\\tool-storage\\rojo-rbx\\rojo\\7.7.0\\rojo.exe";
const logsDir = path.join(projectRoot, "logs");
const outLogPath = path.join(logsDir, "rojo.out.log");
const errLogPath = path.join(logsDir, "rojo.err.log");

fs.mkdirSync(logsDir, { recursive: true });

function append(logPath, message) {
  fs.appendFileSync(logPath, `[${new Date().toISOString()}] ${message}\n`);
}

function startRojo() {
  append(outLogPath, "Starting Rojo keepalive server.");
  const outLog = fs.openSync(outLogPath, "a");
  const errLog = fs.openSync(errLogPath, "a");

  const child = spawn(
    rojoExe,
    ["serve", "default.project.json", "--address", "127.0.0.1", "--port", "34872"],
    {
      cwd: projectRoot,
      windowsHide: true,
      stdio: ["pipe", outLog, errLog],
    },
  );

  child.stdin.write("\n");
  child.on("exit", (code, signal) => {
    append(errLogPath, `Rojo exited with code=${code} signal=${signal}. Restarting in 2 seconds.`);
    setTimeout(startRojo, 2000);
  });
}

process.on("uncaughtException", (error) => {
  append(errLogPath, `Keepalive crashed: ${error && error.stack ? error.stack : error}`);
  setTimeout(startRojo, 2000);
});

startRojo();
