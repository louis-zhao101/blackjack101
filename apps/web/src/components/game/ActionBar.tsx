import { useGameStore } from '../../store/gameStore.js';

interface ActionButtonProps {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  variant?: 'primary' | 'secondary' | 'danger';
  hotkey?: string;
}

function ActionButton({ label, onClick, disabled, variant = 'secondary', hotkey }: ActionButtonProps) {
  return (
    <button
      className={`action-btn action-btn--${variant} ${disabled ? 'action-btn--disabled' : ''}`}
      onClick={onClick}
      disabled={disabled}
      aria-label={`${label}${hotkey ? ` (${hotkey})` : ''}`}
    >
      <span className="action-btn__label">{label}</span>
      {hotkey && <span className="action-btn__hotkey">{hotkey}</span>}
    </button>
  );
}

export function ActionBar() {
  const {
    hit,
    stand,
    double,
    split,
    surrender,
    canDouble,
    canSplit,
    canSurrender,
    game,
  } = useGameStore();

  if (game.phase !== 'PLAYER_TURN') return null;

  return (
    <div className="action-bar" role="group" aria-label="Game actions">
      <ActionButton label="Hit" onClick={hit} variant="primary" hotkey="H" />
      <ActionButton label="Stand" onClick={stand} variant="secondary" hotkey="S" />
      <ActionButton
        label="Double"
        onClick={double}
        disabled={!canDouble()}
        variant="secondary"
        hotkey="D"
      />
      <ActionButton
        label="Split"
        onClick={split}
        disabled={!canSplit()}
        variant="secondary"
        hotkey="P"
      />
      <ActionButton
        label="Surrender"
        onClick={surrender}
        disabled={!canSurrender()}
        variant="danger"
        hotkey="R"
      />
    </div>
  );
}
