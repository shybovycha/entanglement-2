//
//  main.swift
//  entanglement-2
//
//  Created by Artem Shubovych on 06/03/2017.
//  Copyright © 2017 Artem Shubovych. All rights reserved.
//

import Foundation

enum GameError : Error {
    case GameOver
}

enum InternalGameError : Error {
    case InvalidTile
}

class Tile {
    var connections: [(Int, Int)] = []

    func output(from input: Int) throws -> Int {
        for (inPin, outPin) in self.connections {
            if inPin == input {
                return outPin
            }

            if outPin == input {
                return inPin
            }
        }

        throw InternalGameError.InvalidTile
    }

    func outputFromNeighbourOutput(from output: Int) throws -> Int {
        return try self.output(from: self.input(to: output))
    }

    func input(to output: Int) -> Int {
        if (output % 2) == 0 {
            return (output + 12 - 5) % 12
        } else {
            return (output + 12 + 5) % 12
        }
    }

    func rotate(direction: Int) {
        var res: [(Int, Int)] = []

        for (input, output) in self.connections {
            res.append(((input + (direction * 2) + 12) % 12, (output + (direction * 2) + 12) % 12))
        }

        self.connections = res
    }

    // ↻
    func rotateRight() {
        self.rotate(direction: 1)
    }

    // ↺
    func rotateLeft() {
        self.rotate(direction: -1)
    }

    // draw connections
    func render() {
        print("*", terminator: "")
    }

    func toString() -> String {
        return "\(self.connections)"
    }
}

class EmptyTile : Tile {
    // draw an empty space
    override func render() {
        print("o", terminator: "")
    }
}

class NonEmptyTile : Tile {
    override func render() {
        print("@", terminator: "")
    }
}

class ZeroTile : NonEmptyTile {
    override init() {
        super.init()

        self.connections = [(0, 0)]
    }

    override func render() {
        print("0", terminator: "")
    }
}

class BorderTile : NonEmptyTile {
    // draw wall
    override func render() {
        print("x", terminator: "")
    }
}

class PlaceholderTile : Tile {
    override func render() {
        print("_", terminator: "")
    }
}

class PathItem {
    var u: Int, v: Int
    var input: Int
    var output: Int

    init(u: Int, v: Int, input: Int, output: Int) {
        self.u = u
        self.v = v
        self.input = input
        self.output = output
    }
}

class Path {
    var items: [PathItem] = []

    init(centerU u: Int = 4, centerV v: Int = 4) {
        self.expand(u: u, v: v, input: 0, output: 0)
    }

    func expand(u: Int, v: Int, input: Int, output: Int) {
        self.items.append(PathItem(u: u, v: v, input: input, output: output))
    }

    func toString() -> String {
        var res = "x"

        for item in self.items {
            res += " -> [\(item.u), \(item.v)] \(item.input) -> \(item.output)"
        }

        return res
    }

    func lastOutput() -> Int {
        return self.items.last!.output
    }
}

class Field {
    var tiles: [[Tile]] = []
    var path: Path = Path()
    var nextPlace: (Int, Int) = (5, 5)
    var pathFinished: Bool = false

    init() {
        self.tiles = []

        for i in 0...8 {
            self.tiles.append([])

            for _ in 0...8 {
                self.tiles[i].append(PlaceholderTile())
            }
        }

        self.tiles[4][4] = ZeroTile()

        for i in 5...8 {
            for t in 0...(8 - i) {
                self.tiles[t][i + t] = EmptyTile()
                self.tiles[i + t][t] = EmptyTile()
            }
        }

        for i in 0...4 {
            self.tiles[0][i] = BorderTile()
            self.tiles[i][0] = BorderTile()
            self.tiles[8][i + 4] = BorderTile()
            self.tiles[i + 4][8] = BorderTile()
        }

        for i in 1...4 {
            self.tiles[i][i + 4] = BorderTile()
            self.tiles[i + 4][i] = BorderTile()
        }
    }

    func findNextPlace(path: Path, nextPlace: (Int, Int)) -> (Int, Int) {
        var u: Int, v: Int
        (u, v) = nextPlace

        let output: Int = path.lastOutput()

        switch output {
        case 0, 1:
            return (u + 1, v + 1)
        case 2, 3:
            return (u + 1, v)
        case 4, 5:
            return (u, v - 1)
        case 6, 7:
            return (u - 1, v - 1)
        case 8, 9:
            return (u - 1, v)
        case 10, 11:
            return (u, v + 1)
        default:
            return (u, v) // is this correct?
        }
    }

    func isPathFinished() -> Bool {
        return self.pathFinished
    }

    func findFuturePath(tile: NonEmptyTile) throws -> (Path, (Int, Int)) {
        if self.isPathFinished() {
            throw GameError.GameOver
        }

        let tmpPath: Path = Path()
        var tmpNextPlace: (Int, Int) = self.nextPlace
        var u: Int, v: Int

        tmpPath.items = [self.path.items.last!]

        (u, v) = tmpNextPlace

        while true {
            let lastOutput: Int = tmpPath.lastOutput()
            var nextTile: Tile

            if u == self.nextPlace.0 && v == self.nextPlace.1 {
                nextTile = tile
            } else {
                nextTile = self.tiles[u][v]
            }

            if (nextTile is BorderTile) || (nextTile is ZeroTile) {
                self.pathFinished = true
                break
            }

            if !(nextTile is NonEmptyTile) {
                break
            }

            tmpPath.expand(u: u, v: v, input: nextTile.input(to: lastOutput), output: try nextTile.outputFromNeighbourOutput(from: lastOutput))

            tmpNextPlace = self.findNextPlace(path: tmpPath, nextPlace: tmpNextPlace)

            if u == tmpNextPlace.0 && v == tmpNextPlace.1 {
                break
            }

            (u, v) = tmpNextPlace
        }

        tmpPath.items.removeFirst()

        return (tmpPath, tmpNextPlace)
    }

    func placeTile(tile: NonEmptyTile) throws {
        var u: Int, v: Int

        (u, v) = self.nextPlace
        self.tiles[u][v] = tile

        while self.tiles[u][v] is NonEmptyTile {
            let lastOutput: Int = self.path.lastOutput()
            let nextTile = self.tiles[u][v]

            if (nextTile is BorderTile) || (nextTile is ZeroTile) {
                self.pathFinished = true
                break
            }

            self.path.expand(u: u, v: v, input: nextTile.input(to: lastOutput), output: try nextTile.outputFromNeighbourOutput(from: lastOutput))

            self.nextPlace = self.findNextPlace(path: self.path, nextPlace: self.nextPlace)

            if u == self.nextPlace.0 && v == self.nextPlace.1 {
                break
            }

            (u, v) = self.nextPlace
        }

        (u, v) = self.nextPlace
    }

    func render() {
        for row in self.tiles {
            for tile in row {
                tile.render()
            }

            print("")
        }
    }
}

class Game {
    var field: Field = Field()
    var pocket: NonEmptyTile = NonEmptyTile()
    var nextTile: NonEmptyTile = NonEmptyTile()
    var score: Int = 0

    var state: String {
        return "Is over: \(self.isGameOver())\nNext tile: \(self.nextTile.toString())\nPocket: \(self.pocket.toString())\nPath: \(self.field.path.toString())"
    }

    init() {
        self.nextTile = self.generateTile()
        self.pocket = self.generateTile()
    }

    func isGameOver() -> Bool {
        return self.field.isPathFinished()
    }

    func usePocket() {
        swap(&self.pocket, &self.nextTile)
    }

    func rotateTileRight() {
        self.nextTile.rotateRight()
    }

    func rotateTileLeft() {
        self.nextTile.rotateLeft()
    }

    func placeTile() throws {
        if isGameOver() {
            throw GameError.GameOver
        }

        let points = try self.pointsCouldBeGathered()

        try self.field.placeTile(tile: self.nextTile)
        self.nextTile = self.generateTile()
        self.score += points
    }

    func generateTile() -> NonEmptyTile {
        let tile = NonEmptyTile()

        var pool = [Int](0...11)

        for _ in 0...5 {
            var i = Int(arc4random_uniform(UInt32(pool.count)))
            let a = pool[i]
            pool.remove(at: i)
            i = Int(arc4random_uniform(UInt32(pool.count)))
            let b = pool[i]
            pool.remove(at: i)

            tile.connections.append((a, b))
        }

        return tile
    }

    func pointsCouldBeGathered() throws -> Int {
        var points: Int = 0

        let (futurePath, (_, _)) = try self.field.findFuturePath(tile: self.nextTile)

        for i in 0...futurePath.items.count - 1 {
            points += i + 1
        }

        return points
    }
}

func main() throws {
    let game = Game()
    game.field.render()

    while !game.isGameOver() {
        print("========")

        do {
            try game.placeTile()

            game.field.render()

            print("Points: \(game.score)")
        } catch GameError.GameOver {
        }

    }

    print("========\nGame over")
}

try main()
