import os
import asyncio
import pytest
from unittest.mock import AsyncMock
from mavsdk import Offboard, PositionNedYaw
from mavsdk import System

@pytest.mark.asyncio
async def test_start_offboard_mode():

    mock_drone = AsyncMock(spec=System)
    
    mock_offboard = AsyncMock(spec=Offboard)
    mock_drone.offboard = mock_offboard

    mock_offboard.start.return_value = asyncio.Future()
    mock_offboard.start.return_value.set_result(None)
    
    await mock_drone.offboard.start()
    
    mock_offboard.start.assert_awaited_once()
