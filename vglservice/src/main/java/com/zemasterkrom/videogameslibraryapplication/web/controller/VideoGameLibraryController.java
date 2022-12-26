package com.zemasterkrom.videogameslibraryapplication.web.controller;

import com.zemasterkrom.videogameslibraryapplication.dao.IdentifierBuilder;
import com.zemasterkrom.videogameslibraryapplication.dao.VideoGameRepository;
import com.zemasterkrom.videogameslibraryapplication.model.VideoGame;
import jakarta.transaction.Transactional;
import jakarta.validation.ConstraintViolationException;
import org.hibernate.HibernateException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;
import java.util.Set;

/**
 * Controller allowing to modify the video games library
 */
@Controller
public class VideoGameLibraryController {

    /**
     * Autowired link towards the VGL DAO
     */
    private final VideoGameRepository vgldao;

    @Autowired
    public VideoGameLibraryController(VideoGameRepository dao) {
        this.vgldao = dao;
    }

    /**
     * In case of incorrect syntax auto-detection, return a 400 error
     * @return 400 BAD REQUEST response
     */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Integer> returnBadRequestError() {
        return new ResponseEntity<>(HttpStatus.BAD_REQUEST);
    }

    /**
     * Find all video games sorted by ID
     * @return List of all existing video games
     */
    @ResponseBody
    @GetMapping(value = "/video-games/all")
    public Set<VideoGame> getAllVideoGames() {
        return vgldao.findAll();
    }

    /**
     * Find a specific video game
     * @param identifier Identifier (ID or name) of the game to search
     * @return Video game found (if found), otherwise code 204, 503 if internal error
     */
    @ResponseBody
    @GetMapping(value = "/video-games/{identifier}")
    public ResponseEntity<?> getVideoGame(@DefaultValue("") @PathVariable String identifier) {
        Integer integerId = IdentifierBuilder.buildId(identifier);
        return vgldao.existsByIdOrName(integerId, identifier) ? new ResponseEntity<>(vgldao.findByIdOrName(integerId, identifier), HttpStatus.OK) : new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }

    /**
     * Add a video game
     * @param vg Video game to add
     * @return HTTP response: 409 if already existing, 400 if request badly formed, 201 if created, 503 if internal error
     */
    @PostMapping(value = "/video-games/add")
    public ResponseEntity<Integer> addVideoGame(@RequestBody VideoGame vg) {
        try {
            if (!vgldao.existsByIdOrName(vg.getId(), vg.getName())) {
                VideoGame result = vgldao.save(vg);
                return result.getId() >= 0 ? new ResponseEntity<>(HttpStatus.CREATED) : new ResponseEntity<>(HttpStatus.BAD_REQUEST);
            } else {
                return new ResponseEntity<>(HttpStatus.CONFLICT);
            }
        } catch (HibernateException e) {
            return new ResponseEntity<>(HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    /**
     * Modify an existing video game
     * @param identifier Identifier (ID or name) of the game to modify
     * @param vg Video game to modify
     * @return HTTP response: 404 if not existing, 400 if request badly formed, 200 if existing and returned, 503 if internal error
     */
    @PutMapping(value = "/video-games/modify/{identifier}")
    public ResponseEntity<Integer> modifyVideoGame(@DefaultValue("") @PathVariable("identifier") String identifier, @RequestBody VideoGame vg) {
        try {
            Integer integerId = IdentifierBuilder.buildId(identifier);
            Optional<VideoGame> rvg = vgldao.findByIdOrName(integerId, identifier);

            if (rvg.isPresent()) {
                VideoGame realVideoGame = rvg.get();
                if ((realVideoGame.getId().equals(vg.getId()) || realVideoGame.getName().equals(vg.getName())) || !vgldao.existsByIdOrName(vg.getId(), vg.getName())) {
                    vg.setId(realVideoGame.getId());
                    VideoGame result = vgldao.save(vg);
                    return result.getId() >= 0 ? new ResponseEntity<>(HttpStatus.OK) : new ResponseEntity<>(HttpStatus.BAD_REQUEST);
                } else {
                    return new ResponseEntity<>(HttpStatus.CONFLICT);
                }
            } else {
                return new ResponseEntity<>(HttpStatus.NOT_FOUND);
            }
        } catch (HibernateException e) {
            return new ResponseEntity<>(HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    /**
     * Delete an existing video game
     * @param identifier Identifier (ID or name) of the game to delete
     * @return HTTP response: 404 if not existing, 400 if badly formed request, 200 if deleted, 503 if internal error
     */
    @Transactional
    @DeleteMapping(value = "/video-games/delete/{identifier}")
    public ResponseEntity<Integer> deleteVideoGame(@DefaultValue("") @PathVariable("identifier") String identifier) {
        try {
            Integer integerId = IdentifierBuilder.buildId(identifier);

            if (vgldao.existsByIdOrName(integerId, identifier)) {
                vgldao.deleteByIdOrName(integerId, identifier);
                return new ResponseEntity<>(HttpStatus.OK);
            } else {
                return new ResponseEntity<>(HttpStatus.NOT_FOUND);
            }
        } catch (HibernateException e) {
            return new ResponseEntity<>(HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    /**
     * Delete all games
     * @return HTTP response: 200 if OK, 503 if internal error
     */
    @Transactional
    @DeleteMapping(value = "/video-games/delete")
    public ResponseEntity<Integer> deleteAllVideoGames() {
        try {
            vgldao.deleteAll();
            return new ResponseEntity<>(HttpStatus.OK);
        } catch (HibernateException e) {
            return new ResponseEntity<>(HttpStatus.SERVICE_UNAVAILABLE);
        }
    }
}
