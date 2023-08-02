package com.zemasterkrom.videogameslibraryapplication.model;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Objects;

/**
 * Class representing the entity of a video game.
 */
@Entity(name = "VideoGame")
@Table(name = "VideoGame")
public class VideoGame {

    /**
     * Video game identifier
     */
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Integer id;

    /**
     * Video game name
     */
    @NotBlank
    @Column(unique = true)
    private String name;

    /**
     * Video game editor
     */
    @NotBlank
    @NotNull
    private String editor;

    /**
     * Video game description
     */
    @NotNull
    @Column(columnDefinition = "TEXT")
    private String description;

    /**
     * Video game release date
     */
    @NotNull
    @JsonFormat(pattern = "dd/MM/yyyy")
    private Date releasedDate;

    public VideoGame() {
        this.id = -1;
        this.name = "";
        this.editor = "";
        this.description = "";

        try {
            this.releasedDate = new SimpleDateFormat("dd/MM/yyyy").parse("01/01/0001");
        } catch (ParseException ignored) {
        }
    }

    public Integer getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) throws IllegalArgumentException {
        this.name = name;
    }

    public String getEditor() {
        return editor;
    }

    public void setEditor(String editor) throws IllegalArgumentException {
        this.editor = editor;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Date getReleasedDate() {
        return releasedDate;
    }

    public void setReleasedDate(Date releasedDate) throws IllegalArgumentException {
        this.releasedDate = releasedDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        VideoGame videoGame = (VideoGame) o;
        return id.equals(videoGame.id) && name.equals(videoGame.name) && editor.equals(videoGame.editor) && description.equals(videoGame.description) && releasedDate.equals(videoGame.releasedDate);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id, name, editor, description, releasedDate);
    }
}
