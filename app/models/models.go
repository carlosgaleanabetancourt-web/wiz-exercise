package models

import (
	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Todo struct {
	ID     primitive.ObjectID `bson:"_id" json:"ID"`
	Name   string             `bson:"name" json:"name"`
	Status string             `bson:"status" json:"status"`
	UserID string             `bson:"userid" json:"user_id"`
}

type User struct {
	ID       primitive.ObjectID `bson:"_id"`
	Name     *string            `bson:"name" json:"username"`
	Email    *string            `bson:"email" json:"email"`
	Password *string            `bson:"password" json:"password"`
}
