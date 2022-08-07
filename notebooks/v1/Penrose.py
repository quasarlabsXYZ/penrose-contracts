#          _          _            _             _           _            _            _      
#         /\ \       /\ \         /\ \     _    /\ \        /\ \         / /\         /\ \    
#        /  \ \     /  \ \       /  \ \   /\_\ /  \ \      /  \ \       / /  \       /  \ \   
#       / /\ \ \   / /\ \ \     / /\ \ \_/ / // /\ \ \    / /\ \ \     / / /\ \__   / /\ \ \  
#      / / /\ \_\ / / /\ \_\   / / /\ \___/ // / /\ \_\  / / /\ \ \   / / /\ \___\ / / /\ \_\ 
#     / / /_/ / // /_/_ \/_/  / / /  \/____// / /_/ / / / / /  \ \_\  \ \ \ \/___// /_/_ \/_/ 
#    / / /__\/ // /____/\    / / /    / / // / /__\/ / / / /   / / /   \ \ \     / /____/\    
#   / / /_____// /\____\/   / / /    / / // / /_____/ / / /   / / /_    \ \ \   / /\____\/    
#  / / /      / / /______  / / /    / / // / /\ \ \  / / /___/ / //_/\__/ / /  / / /______    
# / / /      / / /_______\/ / /    / / // / /  \ \ \/ / /____\/ / \ \/___/ /  / / /_______\   
# \/_/       \/__________/\/_/     \/_/ \/_/    \_\/\/_________/   \_____\/   \/__________/   
import base64

class Penrose:

# <constuctor>--------------------------------------------------------------------------------------------------------------------

    def __init__(self):
        self.ONE = int("100000000", base=16)
        self.SIZE = 64
        self.HALF_SIZE = self.SIZE // 2

        self.SCHEME = {
            "1": "..+-/",
            "2": ".X/\.",
            "3": "..-\.",
            "4": "..\/|",
            "5": ".O....",
        }

        self.COLORSCHEME = {
            "1": "ffffff000000", # White + Black
            "2": "000000ffffff", # Black + White
        }

        self.numTokens = 0

        self.tokenIdToSeed = {}
        self.seedToId = {}
        self.tokenIdToScheme = {}
        self.tokenIdToColorScheme = {}

# <helpers>--------------------------------------------------------------------------------------------------------------------

    def _getScheme(self, tokenId):
        index = self.tokenIdToSeed[tokenId] % 83

        if index < 20:
            scheme = self.SCHEME["1"]
        elif index < 45:
            scheme = self.SCHEME["2"]
        elif index < 70:
            scheme = self.SCHEME["3"]
        elif index < 80:
            scheme = self.SCHEME["4"]
        else:
            scheme = self.SCHEME["5"]

        return scheme

    def _getColorScheme(self, tokenId):
        index = self.tokenIdToSeed[tokenId] % 30
        
        if index < 25:
            scheme = self.COLORSCHEME["1"]
        else:
            scheme = self.COLORSCHEME["2"]

        return scheme

    def _for_each_col(self, j, tokenId, y, resstr, mod):
        if (j == self.SIZE):
            return resstr

        x = (2 * (j - self.HALF_SIZE) + 1)
        if (self.tokenIdToSeed[tokenId] % 2 == 1):
            x = abs(x)

        x = x * int(self.tokenIdToSeed[tokenId])
        v = abs(int(x * y / self.ONE % mod))

        if (v < 5):
            value = self.tokenIdToScheme[tokenId][v]
        else:
            value = "."

        resstr += f"{value}"

        j = j + 1

        return self._for_each_col(j, tokenId, y, resstr, mod)

    def _for_each_row(self, i, tokenId, output, mod):
        if (i == self.SIZE):
            return output
        
        resstr = ""

        y = (2 * (i - self.HALF_SIZE) + 1)
        if (self.tokenIdToSeed[tokenId] % 3 == 1):
            y = -y
        elif (self.tokenIdToSeed[tokenId] % 3 == 2):
            y = abs(y)

        y = y * int(self.tokenIdToSeed[tokenId])

        j = 0

        output.append(self._for_each_col(j, tokenId, y, resstr, mod))

        i = i + 1

        return self._for_each_row(i, tokenId, output, mod)

    def _draw(self, tokenId):
        mod = (self.tokenIdToSeed[tokenId] % 11) + 5
        output = []
        
        i = 0

        results = self._for_each_row(i, tokenId, output, mod)

        return results

    def _addLine(self, i, pos, step, uri, tokenRawURI):
        if (i == self.SIZE):
            return uri

        uri += f'<text x="50%" y="'
        uri += str(pos)
        uri += '%" class="base" text-anchor="middle">'
        uri += tokenRawURI[i]
        uri += '</text>'

        pos += step
        i = i + 1

        return self._addLine(i, pos, step, uri, tokenRawURI)

    def _wrapToSVG(self, tokenId):
        uri = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 400 400"><defs><style>@font-face{font-family:"Penrose";src:url("./Penrose.ttf");}</style></defs><style>.base { fill: #'
        uri += self.tokenIdToColorScheme[tokenId][:6]
        uri += '; font-family: "Penrose", monospace;font-size: 5px;}</style><rect width="100%" height="100%" fill="#'
        uri += self.tokenIdToColorScheme[tokenId][6:]
        uri += '" />'

        tokenRawURI = self._draw(tokenId)
        
        i = 0
        start = 10
        step = (100 - start * 2) / self.SIZE
        uri = self._addLine(i, start, step, uri, tokenRawURI)
        uri += '</svg>'

        return uri

    def _generateURI(self, tokenId):
        uri = "data:image/svg+xml;base64,"
        svg_bytes = self._wrapToSVG(tokenId).encode('ascii')
        base64_bytes = base64.b64encode(svg_bytes)
        uri += base64_bytes.decode('ascii')

        return uri

# <public methods>--------------------------------------------------------------------------------------------------------------------

    def tokenURI(self, tokenId):
        return self._generateURI(str(tokenId))

    def tokenSVG(self, tokenId):
        return self._wrapToSVG(str(tokenId))

    def tokenRawURI(self, tokenId):
        return self._draw(str(tokenId))

    def scheme(self, tokenId):
        return self.tokenIdToScheme[str(tokenId)]

    def mint(self, seed):
        tokenId = str(self.numTokens + 1)

        self.tokenIdToSeed[tokenId] = seed
        self.seedToId[str(seed)] = tokenId

        scheme = self._getScheme(tokenId)
        self.tokenIdToScheme[tokenId] = scheme

        colorScheme = self._getColorScheme(tokenId)
        self.tokenIdToColorScheme[tokenId] = colorScheme

        uri = self._wrapToSVG(tokenId)

        self.numTokens += 1

        return uri