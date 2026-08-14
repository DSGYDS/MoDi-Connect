const StreamState = Object.freeze({
  IDLE: 'IDLE',
  PERMISSION_REQUESTING: 'PERMISSION_REQUESTING',
  CONNECTING: 'CONNECTING',
  STREAMING: 'STREAMING',
  ERROR: 'ERROR'
});

const state = {
  screen: 'audio',
  stream: StreamState.IDLE,
  selectedPipeline: 'speaker',
  versionTapCount: 0,
  devMode: false,
  holdStartedAt: 0,
  holdFrame: 0,
  pendingAction: '',
  timers: []
};

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const clearTimers = () => { state.timers.forEach(clearTimeout); state.timers = []; };

function setStreamState(nextState) {
  if (!Object.values(StreamState).includes(nextState)) return;
  state.stream = nextState;
  const button = $('#streamButton');
  const stage = $('#stageArea');
  const labels = {
    IDLE: ['开始<br>推流', '开始推流'],
    PERMISSION_REQUESTING: ['授权中…', '正在请求授权'],
    CONNECTING: ['连接中…', '正在连接'],
    STREAMING: ['停止', '长按停止推流'],
    ERROR: ['重试', '连接错误，重试']
  };
  button.dataset.state = nextState;
  stage.dataset.streamState = nextState;
  $('.stream-label', button).innerHTML = labels[nextState][0];
  button.setAttribute('aria-label', labels[nextState][1]);
  if (nextState !== StreamState.STREAMING) {
    button.style.setProperty('--hold-progress', '0turn');
    button.classList.remove('is-holding');
  }
}

function selectPipeline(id) {
  const target = $(`[data-pipeline-id="${id}"]`);
  if (!target) return;
  state.selectedPipeline = id;
  $$('.pipeline-card').forEach((card) => {
    const selected = card === target;
    card.classList.toggle('is-selected', selected);
    card.setAttribute('aria-checked', String(selected));
  });
}

function startStreamingFlow() {
  clearTimers();
  setStreamState(StreamState.PERMISSION_REQUESTING);
  state.timers.push(setTimeout(() => setStreamState(StreamState.CONNECTING), 650));
  state.timers.push(setTimeout(() => setStreamState(StreamState.STREAMING), 1450));
}

function beginStopHold(event) {
  if (state.stream !== StreamState.STREAMING || state.holdStartedAt) return;
  if (event?.pointerId != null) $('#streamButton').setPointerCapture?.(event.pointerId);
  state.holdStartedAt = performance.now();
  navigator.vibrate?.(10);
  $('#streamButton').classList.add('is-holding');
  const tick = (now) => {
    if (!state.holdStartedAt) return;
    const progress = Math.min(1, (now - state.holdStartedAt) / 800);
    $('#streamButton').style.setProperty('--hold-progress', `${progress}turn`);
    if (progress >= 1) {
      state.holdStartedAt = 0;
      navigator.vibrate?.([18, 32, 28]);
      setStreamState(StreamState.IDLE);
      showToast('推流已停止');
      return;
    }
    state.holdFrame = requestAnimationFrame(tick);
  };
  state.holdFrame = requestAnimationFrame(tick);
}

function cancelStopHold() {
  if (!state.holdStartedAt) return;
  state.holdStartedAt = 0;
  cancelAnimationFrame(state.holdFrame);
  const button = $('#streamButton');
  button.classList.remove('is-holding');
  button.animate?.([{ transform: 'scale(.96)' }, { transform: 'scale(1)' }], { duration: 300, easing: 'ease-out' });
  button.style.setProperty('--hold-progress', '0turn');
}

function navigate(screen) {
  if (!['audio', 'profile', 'settings'].includes(screen)) return;
  state.screen = screen;
  $$('.screen').forEach((view) => {
    const active = view.dataset.screen === screen;
    view.hidden = !active;
    view.classList.toggle('is-active', active);
  });
  const primaryTab = screen === 'settings' ? 'profile' : screen;
  $$('.nav-item').forEach((item) => {
    const selected = item.dataset.navigate === primaryTab;
    item.classList.toggle('is-selected', selected);
    selected ? item.setAttribute('aria-current', 'page') : item.removeAttribute('aria-current');
  });
  $('#bottomNav').hidden = screen === 'settings';
  $('#device').classList.toggle('settings-open', screen === 'settings');
}

let toastTimer = 0;
function showToast(message) {
  const toast = $('#toast');
  toast.textContent = message;
  toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toast.hidden = true; }, 2600);
}

function registerVersionTap() {
  if (state.devMode) {
    showToast('您已处于开发者模式');
    return;
  }
  state.versionTapCount += 1;
  if (state.versionTapCount > 2 && state.versionTapCount < 5) {
    showToast(`再点击 ${5 - state.versionTapCount} 次即可进入开发者模式`);
  }
  if (state.versionTapCount === 5) {
    state.devMode = true;
    $('#developerGroup').hidden = false;
    navigator.vibrate?.(28);
    showToast('您已处于开发者模式');
  }
}

function openConfirmDialog(action) {
  state.pendingAction = action;
  $('#confirmMessage').textContent = `确定要${action}吗？此操作不可撤销。`;
  $('#confirmDialog').showModal();
}

function applyAudioSetting(setting) {
  state.pendingAction = setting;
  if (state.stream === StreamState.STREAMING) {
    $('#audioSettingDialog').showModal();
  } else {
    showToast(`${setting}已打开`);
  }
}

function toggleTheme() {
  const root = document.documentElement;
  const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
  root.dataset.theme = next;
  $('#themeToggle').textContent = next === 'dark' ? '浅色' : '深色';
}

function hydratePreviewState() {
  const params = new URLSearchParams(window.location.search);
  const previewTheme = params.get('theme');
  const previewStream = params.get('state');
  const previewScreen = params.get('screen');
  const systemTheme = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  const resolvedTheme = previewTheme === 'dark' || previewTheme === 'light' ? previewTheme : systemTheme;
  document.documentElement.dataset.theme = resolvedTheme;
  $('#themeToggle').textContent = resolvedTheme === 'dark' ? '浅色' : '深色';
  if (Object.values(StreamState).includes(previewStream)) setStreamState(previewStream);
  if (['audio', 'profile', 'settings'].includes(previewScreen)) navigate(previewScreen);
  if (params.get('dev') === '1') {
    state.versionTapCount = 5;
    state.devMode = true;
    $('#developerGroup').hidden = false;
  }
  if (params.get('dialog') === 'danger') setTimeout(() => openConfirmDialog('重置配置'), 50);
  if (params.get('dialog') === 'audio') setTimeout(() => $('#audioSettingDialog').showModal(), 50);
}

$$('.pipeline-card').forEach((card) => card.addEventListener('click', () => selectPipeline(card.dataset.pipelineId)));
$$('[data-navigate]').forEach((control) => control.addEventListener('click', () => navigate(control.dataset.navigate)));
$$('[data-danger-action]').forEach((control) => control.addEventListener('click', () => openConfirmDialog(control.dataset.dangerAction)));
$$('[data-audio-setting]').forEach((control) => control.addEventListener('click', () => applyAudioSetting(control.dataset.audioSetting)));

const streamButton = $('#streamButton');
streamButton.addEventListener('click', () => {
  if (state.stream === StreamState.IDLE || state.stream === StreamState.ERROR) startStreamingFlow();
});
streamButton.addEventListener('pointerdown', beginStopHold);
streamButton.addEventListener('pointerup', cancelStopHold);
streamButton.addEventListener('pointercancel', cancelStopHold);
streamButton.addEventListener('pointerleave', cancelStopHold);
streamButton.addEventListener('keydown', (event) => {
  if ((event.key === ' ' || event.key === 'Enter') && state.stream === StreamState.STREAMING) beginStopHold();
});
streamButton.addEventListener('keyup', cancelStopHold);

$('#versionRow').addEventListener('click', registerVersionTap);
$('#themeToggle').addEventListener('click', toggleTheme);
$('#errorTrigger').addEventListener('click', () => { clearTimers(); setStreamState(StreamState.ERROR); navigate('audio'); });
$('#forceDisconnect').addEventListener('click', () => { setStreamState(StreamState.IDLE); showToast('连接已断开'); });
$('#confirmAction').addEventListener('click', () => showToast(`${state.pendingAction}完成`));
$('#applyAudioSettingAction').addEventListener('click', () => { setStreamState(StreamState.IDLE); showToast('参数已应用，请手动重新连接'); });
document.addEventListener('visibilitychange', () => {
  $('#stageArea').style.animationPlayState = document.hidden ? 'paused' : 'running';
  $$('[data-stage-layer]').forEach((layer) => { layer.style.animationPlayState = document.hidden ? 'paused' : 'running'; });
});

hydratePreviewState();

window.MoDiPrototype = { StreamState, state, setStreamState, selectPipeline, beginStopHold, cancelStopHold, navigate, registerVersionTap, openConfirmDialog, applyAudioSetting, toggleTheme, hydratePreviewState };
