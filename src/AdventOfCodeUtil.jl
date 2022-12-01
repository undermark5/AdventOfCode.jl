module AdventOfCodeUtil

using HTTP, Dates, JSON
using Mocking
export setup_files

_base_url(year, day) = "https://adventofcode.com/$year/day/$day"

function _get_cookies()
    if "AOC_SESSION" ∉ keys(ENV)
        error("Session cookie in ENV[\"AOC_SESSION\"] needed to download data.")
    end
    return Dict("session" => ENV["AOC_SESSION"])
end

function _download_data(year, day)
    result = @mock HTTP.get(_base_url(year, day) * "/input", cookies = _get_cookies())
    if result.status == 200
        return result.body
    end
    error("Unable to download data")
end

function _template(year, day)
    utils = "./src/utils.jl"
    rel_path = joinpath("./data", "day$(lpad(day, 2, "0")).txt")
    example_path = joinpath("./data", "day$(lpad(day, 2, "0"))_example.txt")

    """
    # $(_base_url(year, day))
    using AdventOfCodeUtil
    $(isfile(utils) ? "include(\"utils.jl\")\n" : "")
    example = readlines("$example_path")
    input = readlines("$rel_path")

    function part_1(input)
        nothing
    end
    @show part_1(example)
    @show part_1(input)

    function part_2(input)
        nothing
    end
    @show part_2(example)
    @show part_2(input)
    """
end

function _setup_data_file(year, day)
    rel_path = joinpath("./data", "day$(lpad(day, 2, "0")).txt")

    example_path = joinpath(pwd(), joinpath("./data", "day$(lpad(day, 2, "0"))_example.txt"))
    data_path = joinpath(pwd(), rel_path)
    should_return = false
    if isfile(data_path)
        @warn "$data_path already exists. AdventOfCodeUtil will not redownload it"
        should_return = true
    end
    if isfile(example_path)
        @warn "$example_path already exists."
        should_return = true
    end
    if should_return
        return nothing
    end
    if _is_unlocked(year, day)
        data = _download_data(year, day)
        mkpath(splitdir(data_path)[1])
        open(data_path, "w+") do io
            write(io, data)
        end
        touch(example_path)
    end
end

function _is_unlocked(year, day)
    time_req = HTTP.get("http://worldclockapi.com/api/json/est/now")
    current_datetime = JSON.parse(String(time_req.body))["currentDateTime"]
    current_date = Date(current_datetime[1:10])
    is_unlocked = current_date >= Date(year, 12, day)
    if !is_unlocked
        @warn "Advent of Code for year $year and day $day hasn't unlocked yet."
    end
    is_unlocked
end

"""
    setup_files(year, day; force = false)
    setup_files(; force = false)

Downloads the input file for the specified year and date and stores that file in
`data/day_{day}.txt`.
Also sets up a template file in `src/day_{day}.jl` for your script.
`force=true` will recreate the `src` file even if it already exists. 
The `data` file will not be re-downloaded even with `force=true` 
since it's a static file and to reduce load on AdventOfCode's servers.

If `year` and `day` are not provided, the setup defaults to today's date.
"""
function setup_files(year, day; force = false)
    is_unlocked = _is_unlocked(year, day)
    rel_path = joinpath("./src", "day$(lpad(day,2,"0")).jl")
    code_path = joinpath(pwd(), rel_path)
    is_unlocked &&  _setup_data_file(year, day)
    if !force && isfile(code_path)
        @warn "$code_path already exists. To overwrite, re-run with `force=true`"
    else
        mkpath(splitdir(code_path)[1])
        open(code_path, "w+") do io
            write(io, _template(year, day))
        end
    end
    return code_path
end

setup_files(; force = false) = setup_files(year(today()), day(today()), force = force)

end
