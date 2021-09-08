//
// Copyright 2021, Optimizely, Inc. and contributors 
// 
// Licensed under the Apache License, Version 2.0 (the "License");  
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at   
// 
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

public class DecisionTableGenerator {
    
    public static func create(for optimizely: OptimizelyClient) -> DecisionTables {
        let config = optimizely.config!
        let flags = config.getFeatureFlags()
        let allExperiments = config.allExperiments
        
        var decisionTablesMap = [String: FlagDecisionTable]()
        
        for flag in flags.sorted(by: { $0.key < $1.key }) {
            var schemas = [DecisionSchema]()
                        
            var rules = flag.experimentIds.compactMap { expId in
                return allExperiments.filter { $0.id == expId }.first
            }
            
            let rollout = config.project.rollouts.filter { $0.id == flag.rolloutId }.first
            rules.append(contentsOf: rollout?.experiments ?? [])
            
            rules.forEach { rule in
                // rule-id (not key) is used for bucketing 
                schemas.append(BucketDecisionSchema(bucketKey: rule.id, trafficAllocations: rule.trafficAllocation))
            }
            
            // merge [typedAudiences, audiences] in ProjectConfig to a single audiences array.
            // typedAudiences has a higher priority.
            
            var allAudiencIds = [String]()
            rules.forEach { rule in
                rule.audienceIds.forEach { id in
                    if !allAudiencIds.contains(id) {
                        allAudiencIds.append(id)
                    }
                }
            }
            
            var allUserAttributes = [UserAttribute]()
            allAudiencIds.forEach { audienceId in
                guard let audience = config.getAudience(id: audienceId) else { return }
                
                let userAttributes = getUserAttributes(audience: audience)
                userAttributes.forEach { newItem in
                    if allUserAttributes.filter({ $0.stringRepresentation == newItem.stringRepresentation }).isEmpty {
                        allUserAttributes.append(newItem)
                    }
                }
            }
            
            allUserAttributes.forEach {
                schemas.append(AudienceDecisionSchema(audience: $0))
            }
            
            print("\n[Flag]: \(flag.key)")
            print("\n   [Schemas]")
            schemas.forEach {
                print($0)
            }
            
            let body = makeAllInputs(schemas: schemas)
            print("\n   [DecisionTable]")
            
            var bodyInArray = [(String, String)]()
            
            let user = OptimizelyUserContext(optimizely: optimizely, userId: "any-user-id")
            DecisionTables.modeGenerateDecisionTable = true
            body.forEach { input in
                DecisionTables.schemasForGenerateDecisionTable = schemas
                DecisionTables.inputForGenerateDecisionTable = input
                
                let decision = user.decide(key: flag.key)
                let decisionString = decision.variationKey ?? "nil"
                bodyInArray.append((input, decisionString))
                
                print("      \(input) -> \(decisionString)")
            }
            DecisionTables.modeGenerateDecisionTable = false

            decisionTablesMap[flag.key] = FlagDecisionTable(key: flag.key, schemas: schemas, bodyInArray: bodyInArray)
        }
    
        optimizely.decisionTables = DecisionTables(tables: decisionTablesMap)
        saveDecisionTablesToFile(optimizely: optimizely)
        
        return optimizely.decisionTables
    }
    
    static func makeAllInputs(schemas: [DecisionSchema]) -> [String] {
        var sets = [String]()
        
        guard let firstSchema = schemas.first else {
            return sets
        }
        
        sets.append(contentsOf: firstSchema.allLookupInputs)
        
        while sets.count > 0 {
            var item = sets[0]
            if item.count == schemas.count {
                break
            }
                
            item = sets.removeFirst()
            let index = item.count
            let schema = schemas[index]
            sets.append(contentsOf: schema.allLookupInputs.map { item + $0 })
        }
        
        return sets
    }
    
    static func getUserAttributes(audience: Audience) -> [UserAttribute] {
        var userAttributes = [UserAttribute]()
        getUserAttributes(conditionHolder: audience.conditionHolder, result: &userAttributes)
        return userAttributes
    }
    
    static func getUserAttributes(conditionHolder: ConditionHolder, result: inout [UserAttribute]) {
        switch conditionHolder {
        case .leaf(let leaf):
            if case .attribute(let userAttribute) = leaf {
                result.append(userAttribute)
            }
        case .array(let array):
            array.forEach {
                getUserAttributes(conditionHolder: $0, result: &result)
            }
        default:
            // print("ignored conditionHolder: \(conditionHolder)")
            break
        }
    }
    
    static func saveDecisionTablesToFile(optimizely: OptimizelyClient) {
        guard var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("FileManager saveDecisionTablesToFile error")
            return
        }
        
        url.appendPathComponent("decisionTables")
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("FileManager saveDecisionTablesToFile create folder error")
                return
            }
        }
        
        url.appendPathComponent("\(optimizely.sdkKey).table")
        
        var contents = "SDKKey: \(optimizely.sdkKey)\n"
        
        let tables = optimizely.decisionTables.tables
        let sortedFlagKeys = tables.keys.sorted { $0 < $1 }
        sortedFlagKeys.forEach { flagKey in
            let table = tables[flagKey]!
            
            contents += "\n[Flag]: \(flagKey)\n"
            contents += "\n   [Schemas]\n"
            table.schemas.forEach {
                contents += "\($0)\n"
            }
            
            contents += "\n   [DecisionTable]\n"
            
            table.bodyInArray.forEach { (input, decision) in
                contents += "      \(input) -> \(decision)\n"
            }
        }
        
        try? contents.write(to: url, atomically: true, encoding: .utf8)
    }

}
