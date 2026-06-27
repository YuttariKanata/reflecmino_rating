import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ThemeProvider } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { Box, Button, ButtonBase, Divider, Fab, IconButton, Link, Paper, Snackbar, Typography } from '@mui/material';
import Grid from '@mui/material/Unstable_Grid2';
import { gh_dark as theme } from '../theme/gh_dark';
import { generate } from '../puzzle/generate';
import Measure from 'react-measure'
import { Mode, PuzzleData, empty_puzzle_data } from '../puzzle/const';
import Canvas from './Canvas';
import icon_img from '../images/icon.png';
import h2p1_img from '../images/how_to_play_1.gif';
import h2p2_img from '../images/how_to_play_2.gif';
import h2p3_img from '../images/how_to_play_3.png';
import Timer from './Timer';
import { DatePicker, LocalizationProvider } from '@mui/x-date-pickers';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns'
import { format, isAfter, isBefore, setDate } from 'date-fns';
import PauseIcon from '@mui/icons-material/Pause'
import PlayArrowIcon from '@mui/icons-material/PlayArrow'
import ShareIcon from '@mui/icons-material/Share'
import HomeIcon from '@mui/icons-material/Home'
import DoneIcon from '@mui/icons-material/Done'
import RandomDateIcon from '@mui/icons-material/History'
import FlagIcon from '@mui/icons-material/Flag';
import parse from 'date-fns/parse'
import { is_invalid_date } from '../utils/function';
import { decode } from '../puzzle/decode';
import { SaveData, formatMMSS } from './common';

const query_params = Object.fromEntries(window.location.search.slice(1).split('&').map(e => e.split("=")));
const initial_date = (() => {
    const parse_date = parse(query_params.date, "yyyyMMdd", new Date());
    return is_invalid_date(parse_date)
        ? new Date()
        : parse_date;
})();
const custom_puzzle_data = decode(query_params.custom);
const parseSaveData = (raw: string | undefined): SaveData | undefined => {
    if (!raw || raw.length !== 13) return undefined;

    const modeChar = raw[0];
    const dateChar: string = raw.slice(1, 9);
    const timeChar = raw.slice(9, 13);

    const mode: Mode | undefined = modeChar === "h" ? "HellMode" : modeChar === "n" ? "NormalMode" : undefined
    if (mode === undefined) return undefined

    const dateNum = Number(dateChar)
    if (Number.isNaN(dateNum)) return undefined
    if (dateNum < 19000101 || Number(format(new Date(), "yyyyMMdd")) < dateNum) return undefined

    const timeNum = Number(timeChar)
    if (Number.isNaN(timeNum)) return undefined
    if (timeNum < 0 || 5999 < timeNum) return undefined // 5999秒はタイマーの最大値である99:59

    return {
        mode: mode,
        date: parse(dateChar, "yyyyMMdd", new Date),
        time: timeNum
    };
};
const saveData: SaveData | undefined = parseSaveData(query_params.save_data);

const ReflecMino = (): JSX.Element => {

    const [puzzle_data, setPuzzleData] = useState<PuzzleData>(empty_puzzle_data);
    const [solved, setSolved] = useState<boolean>(false);
    const [size, setSize] = useState<{ x: number, y: number }>({ x: 100, y: 100 });
    const [date, setDate] = useState<Date>(initial_date);
    const [playMode, setPlayMode] = useState<Mode>("NormalMode");
    const [isGenerating, setIsGenerating] = useState<boolean>(false);
    const [copied_snackbar_visible, setCopiedSnackbarVisible] = useState<boolean>(false);
    const [oniFlash, setOniFlash] = useState<boolean>(false);
    const [playing, setPlaying] = useState<boolean>(false);
    const [timer_enabled, setTimerEnabled] = useState<boolean>(false);
    const [how2play_visible, setHow2PlayVisible] = useState<boolean>(false);

    const timeRef = useRef(0);

    const listenersRef = useRef(new Set<() => void>());
    const subscribe = useCallback((listener: () => void) => {
        listenersRef.current.add(listener);
        return () => listenersRef.current.delete(listener);
    },[])
    const getSnapshot = useCallback(() => timeRef.current, []);

    useEffect(() => {
        if (timer_enabled && !solved) {
            const id = window.setInterval(() => {
                if (timeRef.current < 5999) timeRef.current += 1;
                listenersRef.current.forEach(l => l());
            }, 1000);

            return () => window.clearInterval(id);
        }

        if (!playing && !solved) {
            timeRef.current = 0;
            listenersRef.current.forEach(l => l());
        }
    }, [timer_enabled, solved, playing]);


    const HandleDateChange = useCallback(
        (value: Date | null) => {
            if (value !== null) {
                if (!is_invalid_date(value)) {
                    const new_date = isBefore(value, new Date()) ? value : new Date();
                    console.log(format(new_date, "yyyyMMdd"));
                    setDate(new_date);
                }
            }
        }, []
    );
    const HandleRandomDate = useCallback(
        () => {
            const start_date = new Date("1900-01-01");
            const end_date = new Date();
            const time_diff = end_date.getTime() - start_date.getTime();
            const random_time = Math.random() * time_diff;
            const random_date = new Date(start_date.getTime() + random_time);
            setDate(random_date);
        }, []
    );
    const onResize = useCallback(
        ({ bounds }: { bounds?: { width?: number, height?: number } }) => {
            setSize({
                x: bounds?.width ?? 0,
                y: bounds?.height ?? 0
            });
        }, []
    );

    const copy_solve_result_to_clipboard = useCallback(
        () => {
            let text;
            const playDateParam = format(date, "yyyyMMdd") === format(new Date(), "yyyyMMdd") ? "" : "?date=" + format(date, "yyyyMMdd");
            switch (playMode) {
                case "NormalMode":
                    text = [
                        `⬛🟧👿 Reflec鬼Mino ${custom_puzzle_data ? "Custom" : format(date, "yyyy/MM/dd")}`,
                        `🟧⬜🟦 https://reflec-oni-mino.github.io/${playDateParam}`,
                        `⬛🟦⬛ Solved in ${formatMMSS(timeRef.current)}`,
                    ].join("\n");
                    break;
                case "HellMode":
                    text = [
                        `👿🟧👿 Reflec鬼Mino ${custom_puzzle_data ? "Custom" : format(date, "yyyy/MM/dd")}`,
                        `🟧⬜🟦 https://reflec-oni-mino.github.io/${playDateParam}`,
                        `👿🟦👿 Solved in ${formatMMSS(timeRef.current)}`,
                    ].join("\n")
                    break;
            }
            navigator.clipboard.writeText(text)
                .then(function () {
                    setCopiedSnackbarVisible(true);
                    window.setTimeout(() => {
                        setCopiedSnackbarVisible(false);
                    }, 2000);
                    console.log("Async: Copying to clipboard was successful");
                }, function (err) {
                    console.error("Async: Could not copy text: ", err);
                });
        }, [date, playMode, timeRef]
    );
    const copy_resign_result_to_clipboard = useCallback(
        () => {
            let text;
            const playDateParam = "date=" + format(date, "yyyyMMdd");
            const saveDataParam = "save_data=" + (playMode === "NormalMode" ? "n" : "h") + format(date, "yyyyMMdd") + timeRef.current.toString().padStart(4, "0")
            switch (playMode) {
                case "NormalMode":
                    text = [
                        `⬛🟧👿 Reflec鬼Mino ${custom_puzzle_data ? "Custom" : format(date, "yyyy/MM/dd")}`,
                        `🟧⬜🟦 https://reflec-oni-mino.github.io/?${playDateParam}&${saveDataParam}`,
                        `⬛🟦⬛ Resigned at ${formatMMSS(timeRef.current)}🏳️`,
                    ].join("\n");
                    break;
                case "HellMode":
                    text = [
                        `👿🟧👿 Reflec鬼Mino ${custom_puzzle_data ? "Custom" : format(date, "yyyy/MM/dd")}`,
                        `🟧⬜🟦 https://reflec-oni-mino.github.io/?${playDateParam}&${saveDataParam}`,
                        `👿🟦👿 Resigned at ${formatMMSS(timeRef.current)}🏳️`,
                    ].join("\n")
                    break;
            }
            navigator.clipboard.writeText(text)
                .then(function () {
                    setCopiedSnackbarVisible(true);
                    window.setTimeout(() => {
                        setCopiedSnackbarVisible(false);
                    }, 2000);
                    console.log("Async: Copying to clipboard was successful");
                }, function (err) {
                    console.error("Async: Could not copy text: ", err);
                });
        }, [date, playMode, timeRef]
    );
    const hellCountRef = useRef(0);
    const add_hell_mode_count = () => {
        setOniFlash(true);
        window.setTimeout(() => {
            const next = hellCountRef.current + 1;
            if (next >= 4) {
                hellCountRef.current = 0;
                game_start("HellMode");
            } else {
                hellCountRef.current = next;
                setOniFlash(false);
            }
        }, 120);
    };

    const reload_page = useCallback(
        () => {
            const url = new URL(window.location.href);
            window.history.replaceState("", "", url.pathname);
            window.location.reload();
        }, []
    );
    const return_to_top = useCallback(
        () => {
            if (size.x > size.y) {

                setPlaying(false);
                window.setTimeout(() => {
                    setPuzzleData(empty_puzzle_data);
                    setSolved(false);
                    setTimerEnabled(false);
                }, 600);
            }
            else {
                reload_page();
            }
        }, [size, reload_page]
    )

    const game_start = useCallback(
        (mode: Mode) => {
            setIsGenerating(true);
            setPlayMode(mode);
            window.setTimeout(() => {
                setPuzzleData(
                    custom_puzzle_data
                        ? custom_puzzle_data
                        : generate(mode, Number(format(date, "yyyyMMdd")))
                );
                setPlaying(true);
                setTimerEnabled(true);
                setIsGenerating(false);
                setOniFlash(false);
            }, 0);
        }, [date, custom_puzzle_data]
    );
    const game_load = useCallback(
        (saveData: SaveData | undefined) => {
            if (!saveData) return
            setIsGenerating(true);
            setPlayMode(saveData.mode);
            window.setTimeout(() => {
                timeRef.current = saveData.time;
                listenersRef.current.forEach(l => l());
                setPuzzleData(
                    custom_puzzle_data
                        ? custom_puzzle_data
                        : generate(saveData.mode, Number(format(saveData.date, "yyyyMMdd")))
                );
                console.log(saveData);
                setPlaying(true);
                setTimerEnabled(true);
                setIsGenerating(false);
                setOniFlash(false);
            }, 0);
        }, [date, custom_puzzle_data]
    );

    const toggle_how2play = useCallback(
        () => {
            setHow2PlayVisible(!how2play_visible);
        }, [how2play_visible]
    );

    return (
        <>
            <ThemeProvider theme={theme}>
                <CssBaseline />
                <Box
                    width={theme.spacing(43)}
                    minHeight={`calc(100vh - ${theme.spacing(4)})`}
                    margin={`${theme.spacing(1)} auto`}
                    sx={{
                        "@media screen and (max-width:704px)": {
                            width: theme.spacing(22)
                        }
                    }}>
                    <Link
                        href={""}
                        onClick={reload_page}
                        variant={"h4"}
                        marginLeft={theme.spacing(0.5)}
                        underline={"none"}
                        color={"#ffffff"}
                    >
                        Reflec<span style={{ color: '#ff3838ff' }}>鬼</span>Mino
                    </Link>
                    <Divider
                        sx={{
                            marginTop: theme.spacing(0.5),
                            marginBottom: theme.spacing(1)
                        }}
                    />
                    < Grid
                        container
                        direction={"column"}
                        flex-wrap={"nowrap"}
                        justifyContent={"flex-start"}
                        alignItems={"flex-end"}
                        alignContent={"center"}
                    >
                        <Paper
                            elevation={0}
                            sx={{
                                zIndex: 1,
                                position: "absolute",
                                height: "146px",
                                width: "146px",
                                borderRadius: "2px",
                                backgroundColor: "#32373f",
                                marginTop: "103.4px",
                                marginRight: "439px",
                                display: timer_enabled ? "none" : "flex",
                                "@media screen and (max-width:704px)": {
                                    marginTop: "375.2px",
                                    marginRight: "103px",
                                },
                                flexDirection: "column",
                                alignItems: "center",
                                justifyContent: "space-evenly"
                            }}
                        >
                            <Typography
                                variant="h4"
                                color="#ffffff"
                                textAlign="center"
                            >
                                Pause
                            </Typography>
                            <Button
                                variant={"outlined"}
                                size={"large"}
                                sx={{
                                    width: theme.spacing(7),
                                    color: "#ffffff",
                                    borderColor: "#ffffff",
                                    "@media screen and (max-width:704px)": {
                                        width: theme.spacing(7)
                                    },
                                    "&:hover": {
                                        color: "#40c0ff",
                                    }
                                }}
                                onClick={copy_resign_result_to_clipboard}
                                endIcon={<FlagIcon />}
                            >
                                Resign
                            </Button>
                        </Paper>
                        <Paper
                            elevation={5}
                            sx={{
                                zIndex: "3",
                                padding: theme.spacing(1),
                                marginTop: theme.spacing(1),
                                marginRight: theme.spacing(1),
                                position: "absolute",
                                width: theme.spacing(20),
                                height: theme.spacing(20),
                                display: solved ? "block" : "none",
                                boxShadow: solved ? undefined : "none",
                                backgroundImage: "linear-gradient(135deg, rgba(255, 128, 30, 1) 15%, rgba(119, 131, 149, 1) 50%, rgba(0, 153, 255, 1) 85%)",
                                "@media screen and (max-width:704px)": {
                                    width: theme.spacing(22),
                                    height: theme.spacing(16),
                                    marginLeft: "0",
                                    marginRight: "0",
                                    marginTop: "0",
                                    marginBottom: theme.spacing(1)
                                },
                            }}
                        />
                        <Paper
                            elevation={5}
                            sx={{
                                zIndex: "3",
                                padding: theme.spacing(1),
                                marginTop: theme.spacing(1),
                                marginRight: theme.spacing(1),
                                position: "absolute",
                                width: theme.spacing(20),
                                height: theme.spacing(20),
                                display: playing || solved ? "block" : "none",
                                boxShadow: solved ? "none" : undefined,
                                backgroundColor: solved ? "#00000000" : undefined,
                                transition: "background-color 1s",
                                "@media screen and (max-width:704px)": {
                                    position: "static",
                                    width: theme.spacing(22),
                                    height: theme.spacing(16),
                                    marginLeft: "0",
                                    marginRight: "0",
                                    marginTop: "0",
                                    marginBottom: theme.spacing(1)
                                },
                            }}
                        >
                            < Grid
                                container
                                direction={"column"}
                                justifyContent={"flex-start"}
                                alignItems={"center"}
                            >
                                <Timer
                                    subscribe={subscribe}
                                    getSnapshot={getSnapshot}
                                    theme={theme}
                                    solved={solved}
                                />
                                <Fab
                                    variant={"extended"}
                                    color={"primary"}
                                    sx={{
                                        zIndex: "1",
                                        display: solved ? "none" : "inline-flex",
                                        height: theme.spacing(2),
                                        padding: "0",
                                        backgroundColor: "#d9dde0",
                                        borderRadius: "0 0 4px 4px",
                                        "&:hover": {
                                            backgroundColor: "#40c0ff"
                                        }
                                    }}
                                    onClick={useCallback(() => setTimerEnabled(!timer_enabled), [timer_enabled])}
                                >
                                    <PauseIcon
                                        sx={{
                                            display: timer_enabled ? "inline-block" : "none",
                                            width: theme.spacing(12),
                                            margin: "0 auto",
                                            color: "#32373f"
                                        }}
                                    />
                                    <PlayArrowIcon
                                        sx={{
                                            display: timer_enabled ? "none" : "inline-block",
                                            width: theme.spacing(12),
                                            margin: "0 auto",
                                            color: "#32373f"
                                        }}
                                    />
                                </Fab>
                                <Typography
                                    variant={"h6"}
                                    color={"#778395FF"}
                                    textAlign={"center"}
                                    display={solved ? "block" : "none"}
                                    height={theme.spacing(2)}
                                    width={theme.spacing(12)}
                                    padding={"auto"}
                                    borderRadius={"0 0 4px 4px"}
                                    sx={{
                                        backgroundColor: "#ffffff"
                                    }}
                                >
                                    Solved
                                </Typography>
                                <Typography
                                    marginTop={theme.spacing(2)}
                                    variant="h4"
                                >
                                    {custom_puzzle_data ? "Custom" : format(date, "yyyy/MM/dd")}
                                </Typography>
                                <Divider
                                    sx={{
                                        marginTop: theme.spacing(0.4),
                                        width: theme.spacing(12),
                                        borderBottomColor: "#ffffff"
                                    }}
                                />
                            </Grid>
                        </Paper>
                        <Paper
                            elevation={5}
                            sx={{
                                padding: theme.spacing(1),
                                width: theme.spacing(43),
                                height: playing && solved ? theme.spacing(22) : theme.spacing(32.65),
                                transition: solved ? "height 1s" : undefined,
                                boxShadow: playing ? undefined : "none",
                                "@media screen and (max-width:704px)": {
                                    width: theme.spacing(22),
                                    height: playing && solved ? theme.spacing(22) : theme.spacing(27.75),
                                    marginLeft: 0,
                                    marginRight: 0
                                }
                            }}
                        >
                            <Measure bounds onResize={onResize}>
                                {({ measureRef }) => (
                                    <Box
                                        ref={measureRef}
                                        width={"100%"}
                                        height={"100%"}
                                        overflow={"hidden"}
                                    >
                                        <Box
                                            zIndex={2}
                                            position={"absolute"}
                                            width={size.x}
                                            height={size.y}
                                            display={solved ? "block" : "none"}
                                        />
                                        <Canvas
                                            width={size.x}
                                            height={size.y}
                                            puzzle_data={puzzle_data}
                                            setPuzzleData={setPuzzleData}
                                            setSolved={setSolved}
                                            timer_enabled={timer_enabled}
                                        />
                                    </Box>
                                )}
                            </Measure>
                        </Paper>
                        <Paper
                            elevation={5}
                            sx={{
                                zIndex: "5",
                                padding: theme.spacing(1),
                                width: theme.spacing(43),
                                height: theme.spacing(32.65),
                                position: "absolute",
                                boxShadow: "none",
                                visibility: how2play_visible ? "visible" : "hidden",
                                opacity: how2play_visible ? "1" : "0",
                                transition: "opacity 0.6s, visibility 0.6s",
                                "@media screen and (max-width:704px)": {
                                    width: theme.spacing(22),
                                    marginLeft: 0,
                                    marginRight: 0
                                }
                            }}
                        >
                            < Grid
                                container
                                direction={"column"}
                                justifyContent={"flex-start"}
                                alignItems={"center"}
                            >
                                <Typography
                                    variant="h3"
                                    marginTop={theme.spacing(2)}
                                >
                                    HowToPlay
                                </Typography>
                                <Typography
                                    variant="h6"
                                    marginTop={theme.spacing(0.5)}
                                >
                                    すべてのタイルを光らせましょう
                                </Typography>
                                < Grid
                                    container
                                    direction={"row"}
                                    flexWrap={"nowrap"}
                                    justifyContent={"flex-start"}
                                    alignItems={"flex-start"}
                                    width={theme.spacing(20)}
                                    height={theme.spacing(16)}
                                    marginTop={theme.spacing(0.5)}
                                    sx={{
                                        overflowX: "scroll",
                                        overflowY: "hidden",
                                        "@media screen and (max-width:704px)": {
                                            width: theme.spacing(20),
                                        }
                                    }}
                                >
                                    <Typography
                                        variant="h5"
                                        margin={`${theme.spacing(0.5)} 0 auto ${theme.spacing(2.5)}`}
                                    >
                                        1.
                                    </Typography>
                                    <img
                                        src={h2p1_img}
                                        alt={"move"}
                                        height={theme.spacing(15)}
                                    />
                                    <Typography
                                        variant="h5"
                                        margin={`${theme.spacing(0.5)} 0 auto ${theme.spacing(1.5)}`}
                                    >
                                        2.
                                    </Typography>
                                    <img
                                        src={h2p2_img}
                                        alt={"move"}
                                        height={theme.spacing(15)}
                                    />
                                    <Typography
                                        variant="h5"
                                        margin={`${theme.spacing(0.5)} 0 auto ${theme.spacing(1.5)}`}
                                    >
                                        3.
                                    </Typography>
                                    <Box
                                        width={"0"}
                                    >
                                        <DoneIcon
                                            fontSize={"large"}
                                            sx={{
                                                position: "relative",
                                                top: theme.spacing(12.2),
                                                left: theme.spacing(4.75)
                                            }}
                                        />
                                    </Box>
                                    <img
                                        src={h2p3_img}
                                        alt={"move"}
                                        height={theme.spacing(15)}
                                        style={{
                                            paddingRight: theme.spacing(4.2)
                                        }}
                                    />
                                </Grid>
                                <Button
                                    disabled={playing || solved}
                                    variant={"outlined"}
                                    size={"large"}
                                    sx={{
                                        width: theme.spacing(10),
                                        marginTop: theme.spacing(2),
                                        color: "#ffffff",
                                        borderColor: "#ffffff",
                                        "&:hover": {
                                            color: "#40c0ff",
                                        }
                                    }}
                                    onClick={toggle_how2play}
                                >
                                    Close
                                </Button>
                            </Grid>
                        </Paper>
                        <Paper
                            elevation={5}
                            sx={{
                                zIndex: "4",
                                padding: theme.spacing(1),
                                width: theme.spacing(43),
                                height: theme.spacing(32.65),
                                position: "absolute",
                                boxShadow: playing ? "none" : undefined,
                                visibility: playing ? "hidden" : "visible",
                                opacity: playing ? "0" : "1",
                                transition: "opacity 0.6s, visibility 0.6s",
                                "@media screen and (max-width:704px)": {
                                    width: theme.spacing(22),
                                    marginLeft: 0,
                                    marginRight: 0
                                }
                            }}
                        >
                            < Grid
                                container
                                direction={"column"}
                                justifyContent={"flex-start"}
                                alignItems={"center"}
                            >
                                <img
                                    src={icon_img}
                                    alt={"icon"}
                                    width={theme.spacing(5)}
                                    height={theme.spacing(5)}
                                    style={{
                                        marginTop: theme.spacing(3)
                                    }}
                                />
                                <Typography
                                    variant="h3"
                                    marginTop={theme.spacing(2)}
                                >
                                    Reflec
                                    <ButtonBase
                                        disabled={isGenerating}
                                        onClick={add_hell_mode_count}
                                        disableRipple
                                        sx={{
                                            display: 'inline-block',
                                            lineHeight: 1,
                                            font: 'inherit',
                                            padding: 0,
                                            minWidth: 0,
                                            verticalAlign: 'baseline',
                                            userSelect: 'none',

                                            // ▼ 通常時：色の脈動
                                            animation: oniFlash
                                                ? 'none'
                                                : 'oniColorPulse 3.4s ease-in-out infinite',

                                            // ▼ クリック時フラッシュ（上書き）
                                            color: oniFlash ? '#ff7d7dff' : undefined,
                                            filter: oniFlash
                                                ? 'drop-shadow(0 0 24px rgba(255, 74, 74, 1))drop-shadow(0 0 24px rgba(255, 74, 74, 1))'
                                                : 'drop-shadow(0 0 0 rgba(255, 74, 74, 0))',

                                            transition: 'color 620ms ease, filter 120ms ease',

                                            '@keyframes oniColorPulse': {
                                                '0%, 100%': {
                                                    color: '#ff4c4cff',
                                                },
                                                '50%': {
                                                    color: '#ff0000ff',
                                                },
                                            },
                                        }}
                                    >
                                        鬼
                                    </ButtonBase>
                                    Mino
                                </Typography>
                                <Typography
                                    variant="h4"
                                    marginTop={theme.spacing(2)}
                                    display={custom_puzzle_data ? "block" : "none"}
                                >
                                    Custom
                                </Typography>
                                <LocalizationProvider dateAdapter={AdapterDateFns}>
                                    < Grid
                                        container
                                        direction={"row"}
                                        justifyContent={"center"}
                                        alignItems={"center"}
                                        width={theme.spacing(14)}
                                        marginTop={theme.spacing(2)}
                                        display={custom_puzzle_data ? "none" : "inline-flex"}
                                    >
                                        <IconButton
                                            sx={{
                                                zIndex: "1",
                                                position: "absolute",
                                                marginLeft: theme.spacing(11)
                                            }}
                                            onClick={HandleRandomDate}
                                        >
                                            <RandomDateIcon />
                                        </IconButton>
                                        <DatePicker
                                            disabled={playing || solved || how2play_visible || custom_puzzle_data !== undefined}
                                            format={"yyyy/MM/dd"}
                                            slotProps={{
                                                textField: {
                                                    variant: "outlined",
                                                    size: "small",
                                                },
                                                openPickerButton: {
                                                    style: {
                                                        marginRight: theme.spacing(2)
                                                    }
                                                }
                                            }}
                                            sx={{
                                                width: "100%"
                                            }}
                                            value={date}
                                            maxDate={new Date()}
                                            onChange={HandleDateChange}
                                        />
                                    </Grid>
                                </LocalizationProvider>
                                <Button
                                    disabled={isGenerating || playing || solved || how2play_visible || isBefore(date, new Date("1900-1-1")) || isAfter(date, new Date())}
                                    variant={"contained"}
                                    size={"large"}
                                    sx={{
                                        display: saveData ? (format(date, "yyyyMMdd") === format(saveData.date, "yyyyMMdd") ? "none" : "inline-flex") : "inline-flex",
                                        width: theme.spacing(10),
                                        marginTop: theme.spacing(3),
                                        backgroundColor: "#ffffff",
                                        "&:hover": {
                                            backgroundColor: "#40c0ff",
                                        }
                                    }}
                                    onClick={() => game_start("NormalMode")}
                                >
                                    {isGenerating ? "Generating..." : "Play"}
                                </Button>
                                <Button
                                    disabled={isGenerating || playing || solved || how2play_visible || isBefore(date, new Date("1900-1-1")) || isAfter(date, new Date())}
                                    variant={"contained"}
                                    size={"large"}
                                    sx={{
                                        display: saveData ? (format(date, "yyyyMMdd") === format(saveData.date, "yyyyMMdd") ? "inline-flex" : "none") : "none",
                                        width: theme.spacing(10),
                                        marginTop: theme.spacing(3),
                                        color: "#ff3838ff",
                                        backgroundColor: "#ffffff",
                                        "&:hover": {
                                            backgroundColor: "#ffbdbdff",
                                        }
                                    }}
                                    onClick={() => game_load(saveData)}
                                >
                                    {isGenerating ? "Generating..." : "Load"}
                                </Button>
                                <Button
                                    disabled={playing || solved || how2play_visible}
                                    variant={"outlined"}
                                    size={"large"}
                                    sx={{
                                        width: theme.spacing(10),
                                        marginTop: theme.spacing(1),
                                        color: "#ffffff",
                                        borderColor: "#ffffff",
                                        "&:hover": {
                                            color: "#40c0ff",
                                        }
                                    }}
                                    onClick={toggle_how2play}
                                >
                                    How to play
                                </Button>
                            </Grid>
                        </Paper>
                        <Paper
                            elevation={5}
                            sx={{
                                overflow: "hidden",
                                width: theme.spacing(43),
                                padding: `${playing && solved ? theme.spacing(1) : "0px"} ${theme.spacing(1)}`,
                                height: playing && solved ? theme.spacing(4.5) : "0px",
                                marginTop: theme.spacing(1),
                                marginBottom: playing && solved ? theme.spacing(1) : "0px",
                                boxShadow: playing ? undefined : "none",
                                transition: playing ? "height 1s, padding 1s, margin-bottom 1s" : "height 0.6s, padding 0.6s, margin-bottom 0.6s",
                                "@media screen and (max-width:704px)": {
                                    width: theme.spacing(22),
                                    height: playing && solved ? theme.spacing(8) : "0px",
                                }
                            }}
                        >
                            < Grid
                                container
                                flexDirection={"row"}
                                flexWrap={"nowrap"}
                                justifyContent={"space-between"}
                                alignItems={"center"}
                                alignContent={"center"}
                                width={"100%"}
                                height={"100%"}
                                sx={{
                                    "@media screen and (max-width:704px)": {
                                        flexDirection: "column",
                                        gap: theme.spacing(1)
                                    }
                                }}
                            >
                                <Button
                                    disabled={!solved}
                                    variant={"outlined"}
                                    size={"large"}
                                    sx={{
                                        width: theme.spacing(20),
                                        color: "#ffffff",
                                        borderColor: "#ffffff",
                                        "@media screen and (max-width:704px)": {
                                            width: theme.spacing(12)
                                        },
                                        "&:hover": {
                                            color: "#40c0ff",
                                        }
                                    }}
                                    onClick={copy_solve_result_to_clipboard}
                                    endIcon={<ShareIcon />}
                                >
                                    Share
                                </Button>
                                <Button
                                    disabled={!solved}
                                    variant={"outlined"}
                                    size={"large"}
                                    sx={{
                                        width: theme.spacing(20),
                                        color: "#ffffff",
                                        borderColor: "#ffffff",
                                        "@media screen and (max-width:704px)": {
                                            width: theme.spacing(12)
                                        },
                                        "&:hover": {
                                            color: "#40c0ff",
                                        }
                                    }}
                                    onClick={return_to_top}
                                    endIcon={<HomeIcon />}
                                >
                                    Top
                                </Button>
                                <Snackbar
                                    anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
                                    open={copied_snackbar_visible}
                                    message="Copied results to clipboard"
                                />
                            </Grid>
                        </Paper>
                        <Box
                            sx={{
                                "@media screen and (max-width:704px)": {
                                    height: playing ? "0" : theme.spacing(5)
                                }
                            }}
                        />
                    </Grid>
                </Box>
                <Typography
                    width={"100%"}
                    textAlign={"center"}
                    color={"#586270"}
                >
                    Copyright © 2024 yavu
                </Typography>
            </ThemeProvider >
        </>
    )
}

export default React.memo(ReflecMino);
// export default App;