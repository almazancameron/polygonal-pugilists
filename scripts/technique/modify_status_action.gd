class_name ModifyStatusAction
extends TechniqueAction

enum Operator {
    MULTIPLY,
    SUBTRACT,
    DIVIDE,
    SET
}

enum Target {
    SELF,
    TARGET
}

@export var effect: Status.StatusEffect
@export var modifier: float = 1.0
@export var operator: Operator = Operator.MULTIPLY
@export var target: Target = Target.TARGET