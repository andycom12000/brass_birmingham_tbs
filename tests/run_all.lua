#!/usr/bin/env lua
--- Simple test runner for Brass Birmingham game logic.
--- Usage: lua tests/run_all.lua

-- Set up package path so require("src/X") works from project root
local sep = package.config:sub(1, 1) -- "/" or "\"
-- Determine project root: this script lives in tests/, so go up one level
local scriptPath = arg[0] or "tests/run_all.lua"
local projectRoot = scriptPath:gsub("[/\\]tests[/\\][^/\\]+$", "")
if projectRoot == scriptPath then projectRoot = "." end

package.path = projectRoot .. "/?.lua;" .. projectRoot .. "/?/init.lua;" .. package.path

-- Minimal test framework
local totalTests = 0
local totalPassed = 0
local totalFailed = 0
local failures = {}

local currentSuite = ""

function describe(name, fn)
    currentSuite = name
    print("\n--- " .. name .. " ---")
    fn()
end

function it(name, fn)
    totalTests = totalTests + 1
    local ok, err = pcall(fn)
    if ok then
        totalPassed = totalPassed + 1
        print("  PASS: " .. name)
    else
        totalFailed = totalFailed + 1
        local entry = currentSuite .. " > " .. name .. "\n    " .. tostring(err)
        failures[#failures + 1] = entry
        print("  FAIL: " .. name)
        print("    " .. tostring(err))
    end
end

function expect(value)
    return {
        toBe = function(expected)
            if value ~= expected then
                error("Expected " .. tostring(expected) .. ", got " .. tostring(value), 2)
            end
        end,
        toBeTrue = function()
            if value ~= true then
                error("Expected true, got " .. tostring(value), 2)
            end
        end,
        toBeFalse = function()
            if value ~= false then
                error("Expected false, got " .. tostring(value), 2)
            end
        end,
        toBeNil = function()
            if value ~= nil then
                error("Expected nil, got " .. tostring(value), 2)
            end
        end,
        toBeGreaterThan = function(expected)
            if not (value > expected) then
                error("Expected " .. tostring(value) .. " > " .. tostring(expected), 2)
            end
        end,
        toBeLessThan = function(expected)
            if not (value < expected) then
                error("Expected " .. tostring(value) .. " < " .. tostring(expected), 2)
            end
        end,
        toBeGreaterOrEqual = function(expected)
            if not (value >= expected) then
                error("Expected " .. tostring(value) .. " >= " .. tostring(expected), 2)
            end
        end,
    }
end

-- Discover and run test files
local testFiles = {}

-- Cross-platform file discovery: try dir (Windows) then ls (Unix)
local cmd
if package.config:sub(1, 1) == "\\" then
    cmd = 'dir /b "' .. projectRoot:gsub("/", "\\") .. '\\tests\\test_*.lua" 2>nul'
else
    cmd = 'ls "' .. projectRoot .. '/tests/test_"*.lua 2>/dev/null'
end
local handle = io.popen(cmd)
if handle then
    for line in handle:lines() do
        line = line:gsub("%s+$", "")  -- trim trailing whitespace/CR
        if line ~= "" then
            -- dir /b returns just filenames; prepend path if needed
            if not line:find("[/\\]") then
                line = projectRoot .. "/tests/" .. line
            end
            testFiles[#testFiles + 1] = line
        end
    end
    handle:close()
end

if #testFiles == 0 then
    print("No test files found (tests/test_*.lua)")
    print("Create test files to get started.")
    os.exit(0)
end

print("=== Brass Birmingham Unit Tests ===")
print("Found " .. #testFiles .. " test file(s)")

for _, file in ipairs(testFiles) do
    local shortName = file:match("[^/\\]+$")
    print("\n>>> " .. shortName)
    local ok, err = pcall(dofile, file)
    if not ok then
        totalFailed = totalFailed + 1
        failures[#failures + 1] = shortName .. " (load error)\n    " .. tostring(err)
        print("  ERROR loading: " .. tostring(err))
    end
end

-- Summary
print("\n=== Results ===")
print(string.format("Total: %d | Passed: %d | Failed: %d", totalTests, totalPassed, totalFailed))

if #failures > 0 then
    print("\nFailures:")
    for i, f in ipairs(failures) do
        print(string.format("  %d) %s", i, f))
    end
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
