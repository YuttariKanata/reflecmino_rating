import { Theme, Typography } from '@mui/material';
import React, { useSyncExternalStore } from 'react';
import { formatMMSS } from './common';

type TimerProp = {
    subscribe: (listener: () => void) => () => void,
    getSnapshot: () => number,
    theme: Theme,
    solved: boolean
}

const Timer = ({ subscribe, getSnapshot, theme, solved }: TimerProp): JSX.Element => {
    const time = useSyncExternalStore(
        subscribe,
        getSnapshot
      );
    return (
        <Typography
            id={"timer"}
            variant={"h3"}
            sx={{
                width: theme.spacing(12),
                height: theme.spacing(5),
                paddingTop: theme.spacing(0.85),
                margin: `${theme.spacing(3)} auto 0 auto`,
                textAlign: "center",
                borderRadius: "4px 4px 0 0",
                borderStyle: "solid",
                borderWidth: "1px",
                borderColor: solved ? "#ffffff" : "#d9dde0",
                borderBottomWidth: "0",
                "@media screen and (max-width:704px)": {
                    marginTop: theme.spacing(1)
                }
            }}
        >
            {formatMMSS(time)}
        </Typography>
    );
};

export default React.memo(Timer);