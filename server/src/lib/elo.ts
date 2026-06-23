const K = 32;

function expected(a: number, b: number): number {
  return 1 / (1 + 10 ** ((b - a) / 400));
}

export function updateElo(
  white: number,
  black: number,
  result: 'white' | 'black' | 'draw',
): { white: number; black: number } {
  const scoreWhite = result === 'white' ? 1 : result === 'draw' ? 0.5 : 0;
  const scoreBlack = 1 - scoreWhite;

  const newWhite = Math.round(white + K * (scoreWhite - expected(white, black)));
  const newBlack = Math.round(black + K * (scoreBlack - expected(black, white)));

  return {
    white: Math.max(100, newWhite),
    black: Math.max(100, newBlack),
  };
}
