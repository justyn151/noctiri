local border_ok, border = pcall(require, "full-border")
if border_ok then
    border:setup({
        type = ui.Border.ROUNDED,
    })
end

local git_ok, git = pcall(require, "git")
if git_ok then
    git:setup({
        order = 1500,
    })
end

function Linemode:size_and_mtime()
    local modified = math.floor(self._file.cha.mtime or 0)
    local date = ""

    if modified > 0 then
        if os.date("%Y", modified) == os.date("%Y") then
            date = os.date("%b %d %H:%M", modified)
        else
            date = os.date("%b %d  %Y", modified)
        end
    end

    local size = self._file:size()
    return string.format("%s  %s", size and ya.readable_size(size) or "-", date)
end
