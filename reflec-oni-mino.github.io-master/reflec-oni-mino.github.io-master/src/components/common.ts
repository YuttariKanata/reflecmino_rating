import { Mode } from "../puzzle/const"

export type Frame = {
    x: number,
    y: number,
    width: number,
    height: number
}

export type SaveData = {
    mode: Mode,
    date: Date
    time: number
}

export const formatMMSS = (seconds: number): string => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
};
