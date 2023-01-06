// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

library Errors {
    string internal constant YT_NOT_SUPPORTED = "yield token not supported";

    string internal constant ONLY_VAULT = "caller not vault";

    string internal constant INVALID_AMOUNT = "invalid Amount";

    string internal constant INVALID_ADDRESS = "invalid address";

    string internal constant CANNOT_HARVEST = "cannot Harvest Reward";

    string internal constant CAP_EXCEEDED = "vault deposit cap exceeded";
}